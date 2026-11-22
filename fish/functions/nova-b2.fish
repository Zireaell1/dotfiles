function nova-b2 --description 'restic on the B2 copy of Nova: read-only key, nothing stored'
    # Opens a shell with the credentials set; `exit` forgets them and removes the cache.
    # Inside, `restic` always gets --no-lock.

    read -l -P 'B2 bucket: ' bucket; or return
    read -l -P 'nova-restore keyID: ' id; or return
    read -l -s -P 'nova-restore applicationKey: ' key; or return
    read -l -s -P 'restic password: ' pass; or return

    # Own cache, removed at the end: restic's default cache (~/Library/Caches/restic) would keep repo metadata
    set -l cache (mktemp -d -t nova-b2)

    env B2_ACCOUNT_ID=$id B2_ACCOUNT_KEY=$key RESTIC_PASSWORD=$pass \
        RESTIC_REPOSITORY="b2:$bucket:homelab" RESTIC_CACHE_DIR=$cache \
        fish -C 'function restic --wraps restic; command restic --no-lock $argv; end
            function fish_right_prompt; set_color yellow; echo "[nova-b2]"; set_color normal; end
            echo "nova-b2: restic is set up for the B2 copy (read-only). exit to forget the credentials."'

    rm -rf $cache
end
