# Estrae i file .patch dalla branch patches
git checkout patches -- *.patch

# Applica ciascun patch
for patch in *.patch; do
    if git apply "$patch"; then
        echo "Patch $patch applicato con successo."
    else
        echo "Errore: il patch $patch non è applicabile."
        exit 1
    fi
done
