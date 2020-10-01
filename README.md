# Local Env Setup

What I use to set up new machines.

## Install

First, you'll need xcode command line tools installed:

```bash
xcode-select --install
```

If the above fails, look at your System Settings > Software Update and see if xcode command line tools is available for update from there.

Once xcode command line tools are installed, you can then pull this repo and run the install script.

```bash
cd ~
git clone git@github.com:jubairsaidi/dotfiles.git .env && cd .env
./install.sh
```
