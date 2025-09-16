#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────
# Config – kann per ENV überschrieben werden
# ─────────────────────────────
KUBECTL_VERSION="${KUBECTL_VERSION:-}"          # leer => "stable"
HELM_VERSION="${HELM_VERSION:-v3.15.4}"         # anpassbar
KUBELOGIN_VERSION="${KUBELOGIN_VERSION:-v1.29.0}"

# ─────────────────────────────
# Helpers
# ─────────────────────────────
die(){ echo "ERROR: $*" >&2; exit 1; }

# Arch ermitteln (BAS läuft i. d. R. x86_64/amd64)
uname_m="$(uname -m)"
case "$uname_m" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) die "Nicht unterstützte Architektur: $uname_m" ;;
esac

# Bin-Verzeichnis anlegen + PATH persistieren
mkdir -p "$HOME/.local/bin"
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

have(){ command -v "$1" >/dev/null 2>&1; }

# ─────────────────────────────
# kubectl installieren
# ─────────────────────────────
install_kubectl(){
  local ver url sumurl
  if [[ -z "$KUBECTL_VERSION" ]]; then
    echo "[kubectl] Ermittle stabile Version…"
    ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" || die "konnte stable.txt nicht laden"
  else
    ver="$KUBECTL_VERSION"
  fi
  url="https://dl.k8s.io/release/${ver}/bin/linux/${ARCH}/kubectl"
  sumurl="${url}.sha256"

  echo "[kubectl] Lade ${ver} (${ARCH})…"
  curl -fsSL -o /tmp/kubectl "$url"
  # Checksumme (best-effort)
  if have sha256sum; then
    echo "[kubectl] Prüfe SHA256…"
    curl -fsSL -o /tmp/kubectl.sha256 "$sumurl"
    sha256sum -c <(awk '{print $1"  /tmp/kubectl"}' /tmp/kubectl.sha256) || die "SHA256-Check fehlgeschlagen"
  fi
  chmod +x /tmp/kubectl
  mv /tmp/kubectl "$HOME/.local/bin/kubectl"
  echo "[kubectl] installiert → $(kubectl version --client --output=yaml | head -n 2)"
}

# ─────────────────────────────
# kubelogin installieren (OIDC für kubectl)
# ─────────────────────────────
install_kubelogin(){
  local base ver file
  ver="${KUBELOGIN_VERSION:-latest}"
  file="kubelogin_linux_${ARCH}.zip"
  if [ "$ver" = "latest" ]; then
    echo "[kubelogin] Lade latest (${ARCH})…"
    curl -fsSL -o /tmp/kubelogin.zip "https://github.com/int128/kubelogin/releases/latest/download/${file}"
  else
    echo "[kubelogin] Lade ${ver} (${ARCH})…"
    curl -fsSL -o /tmp/kubelogin.zip "https://github.com/int128/kubelogin/releases/download/${ver}/${file}"
  fi
  if command -v unzip >/dev/null 2>&1; then
    unzip -p /tmp/kubelogin.zip kubelogin > "$HOME/.local/bin/kubelogin"
  else
    python3 - <<'PY'
import zipfile, sys, os
z=zipfile.ZipFile('/tmp/kubelogin.zip')
with z.open('kubelogin') as src, open(os.path.expanduser('~/.local/bin/kubelogin'),'wb') as dst:
    dst.write(src.read())
PY
  fi
  chmod +x "$HOME/.local/bin/kubelogin"
  echo "[kubelogin] installiert → $(kubelogin --version 2>/dev/null || echo ok)"
}

# ─────────────────────────────
# helm installieren
# ─────────────────────────────
install_helm(){
  local url="/tmp/helm.tgz"
  local base="https://get.helm.sh"
  local file="helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
  echo "[helm] Lade ${HELM_VERSION} (${ARCH})…"
  curl -fsSL -o "$url" "${base}/${file}" || die "Download fehlgeschlagen"
  tar -xzf "$url" -C /tmp "linux-${ARCH}/helm" || die "Entpacken fehlgeschlagen"
  mv "/tmp/linux-${ARCH}/helm" "$HOME/.local/bin/helm"
  chmod +x "$HOME/.local/bin/helm"
  echo "[helm] installiert → $(helm version --short)"
}

# ─────────────────────────────
# Ausführen
# ─────────────────────────────
echo "▶ Installiere Tools in $HOME/.local/bin (ARCH=$ARCH)…"
install_kubectl
install_kubelogin
install_helm

echo
echo "✅ Fertig! Bitte öffne ein neues Terminal (oder: source ~/.bashrc)"
echo "   Versionen:"
kubectl version --client --output=json 2>/dev/null | sed -n '1,2p' || true
kubelogin --version || true
helm version --short || true

cat <<'TIP'

Tipps:
- Kubeconfig der Kyma-Runtime als ~/.kube/config speichern (oder $KUBECONFIG setzen):
    mkdir -p ~/.kube && vi ~/.kube/config
  Dann:
    kubectl cluster-info
- Für Kyma-Login oft nötig:
    kubelogin convert-kubeconfig -l spn
  (oder je nach Vorgabe deiner Landschaft)
TIP
