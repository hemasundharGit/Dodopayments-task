param(
  [switch]$SkipGoTools
)

$ErrorActionPreference = "Stop"

function Test-Cmd {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-Winget {
  param(
    [string]$Id,
    [string]$Name
  )

  if (-not (Test-Cmd winget)) {
    Write-Warning "winget is not installed. Install App Installer from Microsoft Store, then rerun."
    return
  }

  Write-Host "Installing $Name with winget package $Id"
  winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "== Core local Kubernetes and security tooling =="

if (-not (Test-Cmd docker)) {
  Install-Winget -Id "Docker.DockerDesktop" -Name "Docker Desktop"
} else {
  Write-Host "docker already installed"
}

if (-not (Test-Cmd kubectl)) {
  Install-Winget -Id "Kubernetes.kubectl" -Name "kubectl"
} else {
  Write-Host "kubectl already installed"
}

if (-not (Test-Cmd kind)) {
  Install-Winget -Id "Kubernetes.kind" -Name "kind"
} else {
  Write-Host "kind already installed"
}

if (-not (Test-Cmd helm)) {
  Install-Winget -Id "Helm.Helm" -Name "Helm"
} else {
  Write-Host "helm already installed"
}

if (-not (Test-Cmd cosign)) {
  Install-Winget -Id "Sigstore.cosign" -Name "cosign"
} else {
  Write-Host "cosign already installed"
}

if (-not (Test-Cmd trivy)) {
  Install-Winget -Id "AquaSecurity.Trivy" -Name "Trivy"
} else {
  Write-Host "trivy already installed"
}

if (-not (Test-Cmd gitleaks)) {
  Install-Winget -Id "Gitleaks.Gitleaks" -Name "Gitleaks"
} else {
  Write-Host "gitleaks already installed"
}

if (-not (Test-Cmd argocd)) {
  Install-Winget -Id "ArgoCD.ArgoCD" -Name "ArgoCD CLI"
} else {
  Write-Host "argocd already installed"
}

if (-not (Test-Cmd istioctl)) {
  Install-Winget -Id "Istio.Istio" -Name "Istio CLI"
} else {
  Write-Host "istioctl already installed"
}

if (-not (Test-Cmd go)) {
  Install-Winget -Id "GoLang.Go" -Name "Go"
  Write-Host "Go was installed. Open a new PowerShell window before installing Go-based recon tools."
  if (-not $SkipGoTools) {
    Write-Warning "Skipping Go tools in this run because PATH may not be refreshed yet."
  }
  $SkipGoTools = $true
}

if (-not $SkipGoTools) {
  Write-Host "== Go-based recon and pentest tools =="
  go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  go install github.com/owasp-amass/amass/v4/...@master
  go install github.com/tomnomnom/assetfinder@latest
  go install github.com/projectdiscovery/httpx/cmd/httpx@latest
  go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
  go install github.com/ffuf/ffuf/v2@latest
}

Write-Host "== Python-based tools =="
python -m pip install --user --upgrade pip
python -m pip install --user semgrep sqlmap pypdf

Write-Host "== Tools that may still need manual install =="
Write-Host "kubeseal: download from https://github.com/bitnami-labs/sealed-secrets/releases if winget has no package."
Write-Host "kyverno CLI: download from https://github.com/kyverno/kyverno/releases if winget has no package."
Write-Host "whatweb: easiest via WSL/Kali/Ubuntu: sudo apt-get install whatweb."
Write-Host "testssl.sh: git clone --depth 1 https://github.com/drwetter/testssl.sh.git `$HOME/tools/testssl.sh"
Write-Host "OWASP ZAP/Burp Community: install GUI tools manually if needed for screenshots."

Write-Host "== Version check =="
$tools = "git","docker","kubectl","kind","helm","cosign","trivy","gitleaks","argocd","istioctl","go","semgrep","sqlmap","subfinder","amass","assetfinder","httpx","nuclei","ffuf"
foreach ($tool in $tools) {
  $cmd = Get-Command $tool -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Host ("{0,-15} {1}" -f $tool, $cmd.Source)
  } else {
    Write-Host ("{0,-15} MISSING" -f $tool)
  }
}
