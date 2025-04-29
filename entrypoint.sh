#!/bin/bash
set -e

HYPHANET_HOME=${HYPHANET_HOME:-/opt/hyphanet}
HYPHANET_DATA=${HYPHANET_DATA:-/data}

echo "--- Entrypoint Start ---"
echo "DEBUG: Current User: $(whoami)"
echo "DEBUG: HYPHANET_HOME: ${HYPHANET_HOME}"
echo "DEBUG: HYPHANET_DATA: ${HYPHANET_DATA}"
echo "-------------------------"

PERSISTENT_ITEMS=(
    "freenet/freenet.ini"    
    "freenet.ini.bak" 
    "node.random" 
    "master.keys"
    "seednodes.fref" 
    "persistent-temp" 
    "downloads" 
    "plugins"
    "stats" 
    "store" 
    "wrapper.log"
)
echo "Setting up persistence links..."
mkdir -p "${HYPHANET_DATA}"
for item in "${PERSISTENT_ITEMS[@]}"; do
    src_path="${HYPHANET_HOME}/${item}"
    dest_path="${HYPHANET_DATA}/${item}"
    if [ -e "${src_path}" ] && [ ! -e "${dest_path}" ]; then
        mkdir -p "$(dirname "${dest_path}")"
        mv "${src_path}" "${dest_path}"
    fi
    if [ -e "${dest_path}" ]; then
        rm -rf "${src_path}"
        ln -sf "${dest_path}" "${src_path}"
    fi
done
FREENET_INI_PATH="${HYPHANET_DATA}/freenet/freenet.ini"
WRAPPER_LOG_PATH="${HYPHANET_DATA}/wrapper.log"
echo "Persistence setup done."

if [ "$1" = 'start' ]; then
    if [ -f "$FREENET_INI_PATH" ]; then
        echo "Checking/Updating FProxy settings in $FREENET_INI_PATH..."        
        sed -i 's#^fproxy.bindTo=.*#fproxy.bindTo=0.0.0.0,::#g' "$FREENET_INI_PATH"
sed -i 's#^fproxy.allowedHosts=.*#fproxy.allowedHosts=0.0.0.0,::#g' "$FREENET_INI_PATH"
sed -i 's#^fproxy.allowedHostsFullAccess=.*#fproxy.allowedHostsFullAccess=0.0.0.0,::#g' "$FREENET_INI_PATH"
        echo "FProxy settings updated to listen on 0.0.0.0 and allow connections from 0.0.0.0/::."
    else
        echo "WARN: $FREENET_INI_PATH not found. FProxy might not be accessible from host."
    fi    

    echo "Searching for start script..."
    declare -a potential_scripts=(
        "${HYPHANET_HOME}/run.sh" "${HYPHANET_HOME}/Hyphanet/run.sh"
        "${HYPHANET_HOME}/Freenet/run.sh" "${HYPHANET_HOME}/freenet/run.sh"
    )
    found_script=""
    for start_script in "${potential_scripts[@]}"; do
        if [ -f "$start_script" ]; then
            if [ -x "$start_script" ]; then
                found_script="$start_script"
                break
            else
                echo "Making script executable: $start_script"
                chmod +x "$start_script"
                if [ -x "$start_script" ]; then
                    found_script="$start_script"
                    break
                fi
            fi
        fi
    done

    if [ -n "$found_script" ]; then
        echo "Attempting to start Hyphanet in background using: $found_script"        
        "$found_script" start
        
        echo "Waiting 5 seconds for Hyphanet to potentially start..."
        sleep 5

        echo "Tailing log file ($WRAPPER_LOG_PATH) to keep container running..."        
        if [ ! -f "$WRAPPER_LOG_PATH" ]; then
            echo "WARN: Log file $WRAPPER_LOG_PATH not found. Creating empty file."
            touch "$WRAPPER_LOG_PATH"            
        fi        
        tail -f "$WRAPPER_LOG_PATH"
    else
        echo "-------------------------------------------------------------"
        echo "ERROR: Could not find a valid and executable start script!"
        echo "Searched paths:"
        printf " - %s\n" "${potential_scripts[@]}"
        echo "Final content of ${HYPHANET_HOME} (at runtime):"
        ls -lRa "${HYPHANET_HOME}" || echo "WARN: Could not list ${HYPHANET_HOME}"
        echo "-------------------------------------------------------------"
        exit 1
    fi    
else    
    exec "$@"
fi