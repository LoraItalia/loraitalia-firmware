#!/bin/bash

# Funzione per validare il formato del tag
validate_tag() {
    local tag="$1"
    if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9][0-9]+\.([a-z0-9]{7})$ ]]; then
        return 0
    else
        return 1
    fi
}

# Richiede il tag come input
read -p "Inserisci il tag (formato v2.5.19.d5cd6f8): " tag

# Valida il formato del tag
if ! validate_tag "$tag"; then
    echo "Errore: il tag '$tag' non è valido. Deve rispettare il formato v2.5.19.d5cd6f8."
    exit 1
fi

# Checkout del tag
if git checkout "$tag"; then
    echo "Checkout del tag $tag completato."
else
    echo "Errore: il tag $tag non esiste."
    exit 1
fi

# Estrae i file .patch dalla branch patches
git checkout patches-$tag -- *.patch

# Verifica se ci sono file .patch
if ! ls *.patch >/dev/null 2>&1; then
    echo "Nessun file .patch trovato."
    exit 1
fi

# Applica ciascun patch
for patch in *.patch; do
    if git apply "$patch"; then
        echo "Patch $patch applicato con successo."
    else
        echo "Errore: il patch $patch non è applicabile."
        exit 1
    fi
done
