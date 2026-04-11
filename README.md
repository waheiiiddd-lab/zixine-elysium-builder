# 🌌 Zixine Elysium Kernel Builder

Welcome to the **Zixine Elysium Kernel Builder**! This repository provides an automated, robust, and highly optimized environment for building Android GKI (Generic Kernel Image) kernels. 

Currently supporting:
- **GKI 5.10** (Android 12)
- **GKI 6.1** (Android 14)
- **GKI 6.6** (Android 15)

---

## ⚖️ License & Attribution

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

This project is licensed under the **GNU General Public License v2.0 (GPL-2.0)**.
Under the spirit of open-source and GPLv2 compliance, this repository is fully open for use, modification, and redistribution, provided that the source remains open and original authors are credited.

### 🌟 Upstream & Inspiration
**Zixine Elysium** is proudly built upon the strong foundation and concepts of the **Vortex Kernel Builder**. 
Massive respect and profound thanks to **[Kingfinik98 (Vortex)](https://github.com/Kingfinik98)** for their original architecture, CI/CD workflow designs, and relentless bug fixing in the kernel community. We do not claim their underlying automation logic as our own; rather, we adapt and evolve it here for the Elysium project.

*Original Base Repository:* [Kingfinik98/build-vortex](https://github.com/Kingfinik98/build-vortex)

---

## ⚙️ Build Notes & Configuration

Before running the workflow or compiling locally, please take note of the required compiler toolchains:

**Clang Version Requirements:**
- For **GKI 5.10**: Use Clang `12`, `19`, `20`, or `22`
- For **GKI 6.1** & **6.6**: Use Clang `19`, `21`, or `22`

**How to change Clang Version:**
1. Open `build.sh`
2. Find the variable `CLANG_URL`
3. Remove the hash/pound sign (`#`) in front of the specific Clang URL you wish to use, and comment out the others.

---

## 📦 Dependencies & Resources

This build system interacts with several upstream dependencies for root injection and kernel packaging:
- **AnyKernel3:** Adapted from [Kingfinik98/AnyKernel3](https://github.com/Kingfinik98/AnyKernel3)
- **KernelSU Manager Base:** Logic heavily inspired by [VortexSU](https://github.com/Kingfinik98/VortexSU)

---

## 🙏 Credits & Acknowledgments

Aside from the upstream Vortex base, this project owes its gratitude to several key developers in the kernel community for conceptual references, ideas, and patches:

- **[@linastorvaldz](https://github.com/linastorvaldz)** — For conceptual inspiration and upstream references.
- **[@ramabondanp](https://github.com/ramabondanp)** — For kernel common trees and development references.
- **[@kaminarich](https://github.com/kaminarich)** — For continuous conceptual inspiration.

> *"Open source is about standing on the shoulders of giants. We respect the original work, maintain the commit histories, and strive to bring new stability to the Android community."*

---

## 🛡️ Maintainer
**Zixine Elysium Project**
*(If you find this project helpful, consider starring the repository!)*
