
#!/bin/bash

has_sudo() {
    if sudo -l &>/dev/null; then
        return 0
    else
        return 1
    fi
}

if has_sudo; then
    directory_uid=$(stat -c '%u' "$MAMBA_ROOT_PREFIX")
    directory_gid=$(stat -c '%g' "$MAMBA_ROOT_PREFIX")

    if [ "$MAMBA_USER_ID" != "$directory_uid" ] || [ "$MAMBA_USER_GID" != "$directory_gid" ]; then
        sudo chown -R $MAMBA_USER_ID:$MAMBA_USER_GID "$MAMBA_ROOT_PREFIX"
    fi
else
    echo "User does not have sudo permissions. Can't set permissions for $MAMBA_ROOT_PREFIX."
fi
