#!/bin/bash
set -euo pipefail

echo "--- SCIENCE / DATA-SCIENCE POST-INSTALL START ---"

USERNAME="${SUDO_USER:-$USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo!"
  exit 1
fi

echo "Target user: $USERNAME"

# --- Update ---
echo "--- Updating system ---"
pacman -Syu --noconfirm

# --- Development tools ---
echo "--- Installing base dev tools ---"
pacman -S --noconfirm --needed \
  base-devel git vim neovim tmux wget curl unzip zip p7zip

# --- Programming languages ---
echo "--- Installing languages ---"
pacman -S --noconfirm --needed \
  python python-pip python-virtualenv \
  r r-libs \
  julia go nodejs npm ruby rust

# --- Jupyter & Python ecosystem ---
echo "--- Installing Jupyter ecosystem ---"
pacman -S --noconfirm --needed \
  jupyter-notebook jupyterlab

# Optional: Python ML libraries (via pip for latest)
sudo -u $USERNAME pip install --upgrade pip
sudo -u $USERNAME pip install numpy scipy pandas matplotlib seaborn scikit-learn tensorflow torch jupyterlab-git

# --- R & Julia extra packages ---
sudo -u $USERNAME Rscript -e "install.packages(c('tidyverse','data.table','ggplot2','caret','shiny'), repos='https://cloud.r-project.org')"

sudo -u $USERNAME julia -e 'using Pkg; Pkg.add(["DataFrames","Plots","Flux","MLJ"])'

# --- GPU / CUDA / OpenCL (optional, if NVIDIA/AMD) ---
echo "--- Installing GPU acceleration tools ---"
if lspci | grep -qi nvidia; then
  pacman -S --noconfirm --needed nvidia-dkms nvidia-utils cuda
elif lspci | grep -qi amd; then
  pacman -S --noconfirm --needed mesa vulkan-radeon opencl-mesa
fi

# --- Container & reproducible environments ---
echo "--- Installing Docker & Podman ---"
pacman -S --noconfirm --needed docker podman podman-docker buildah

systemctl enable --now docker

# --- Visualization tools ---
echo "--- Installing visualization & plotting tools ---"
pacman -S --noconfirm --needed \
  gnuplot graphviz imagemagick ffmpeg

# --- Productivity & note-taking ---
echo "--- Installing office & note-taking tools ---"
pacman -S --noconfirm --needed \
  libreoffice-fresh zathura zathura-pdf-mupdf \
  obsidian joplin-desktop

# --- Fonts for scientific publications ---
pacman -S --noconfirm --needed \
  ttf-dejavu ttf-liberation noto-fonts \
  ttf-iosevka nerd-fonts-complete

# --- Directories for projects ---
mkdir -p /home/$USERNAME/{Projects,Data,Notebooks,Publications,Scripts}

# --- Environment tuning ---
cat >> /home/$USERNAME/.bashrc <<'EOF'

# === DATA SCIENCE / SCIENCE ENVIRONMENT ===
export PYTHONWARNINGS="ignore"
export JUPYTER_ALLOW_INSECURE_WRITES=1
EOF

chown -R $USERNAME:$USERNAME /home/$USERNAME

# --- Aanbevelingen / optionele extra tools ---
cat <<EOT

💡 Aanbevelingen voor wetenschappers / data scientists:

1. **Python ecosystem**
   - Conda / Miniconda voor environment management
   - Poetry of Pipenv voor reproducible projects
   - JupyterLab extensions: jupyterlab-git, jupyterlab-toc

2. **R**
   - RStudio (IDE)
   - Shiny apps voor web visualisatie
   - Bioconductor voor bio-informatics

3. **Julia**
   - Pluto.jl voor interactieve notebooks
   - MLJ, Flux voor machine learning

4. **GPU / HPC**
   - CUDA toolkit / cuDNN (NVIDIA)
   - ROCm stack (AMD)
   - Singularity / Apptainer voor HPC containers

5. **Data management**
   - PostgreSQL / MariaDB
   - SQLite
   - DVC (Data Version Control)

6. **Workflow / reproducibility**
   - Git & Git LFS
   - Makefiles / Snakemake
   - Docker / Podman for reproducible pipelines

7. **Visualization / plotting**
   - Matplotlib, Seaborn, Plotly
   - Graphviz, Gnuplot
   - ffmpeg for video visualization

EOT

echo "--- SCIENCE INSTALL COMPLETE ---"
echo "Reboot recommended for full performance."