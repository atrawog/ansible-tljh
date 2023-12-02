
    #!/bin/bash

    # Function to check if the user has sudo permissions
    has_sudo() {
        if sudo -l &>/dev/null; then
            return 0
        else
            return 1
        fi
    }

    # Check if the user has sudo permissions
    if has_sudo; then
        # echo "User has sudo permissions."

        # Get the current user's UID and GID
        user_uid=$(id -u)
        user_gid=$(id -g)

        # Get the UID and GID of the directory specified by MAMBA_ROOT_PREFIX
        directory_uid=$(stat -c '%u' "$MAMBA_ROOT_PREFIX")
        directory_gid=$(stat -c '%g' "$MAMBA_ROOT_PREFIX")

        # Compare the UID and GID of the user and the directory
        if [ "$user_uid" != "$directory_uid" ] || [ "$user_gid" != "$directory_gid" ]; then
            # echo "UID and GID of $MAMBA_ROOT_PREFIX differ from the user. Changing them now."
            sudo chown -R $user_uid:$user_gid "$MAMBA_ROOT_PREFIX"
            #echo "UID and GID of $MAMBA_ROOT_PREFIX have been changed to match the user."
        #else
        #    echo "UID and GID of $MAMBA_ROOT_PREFIX already match the user."
        fi
    else
        echo "User does not have sudo permissions. Can't set permissions for $MAMBA_ROOT_PREFIX."
    fi
    