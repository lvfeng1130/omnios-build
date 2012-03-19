#!/usr/bin/bash
SHELL=/usr/bin/bash
export SHELL
SKIP_ROOT_CHECK=1
if [[ -n "$SUDO_USER" ]]; then
    echo "Don't run under sudo, just build as you"
    exit
fi

# Load support functions
. ../../lib/functions.sh

PROG=caiman    # App name
VER=151.3    # App version
PVER=1          # Package Version (numeric only)
PKG=caiman
SUMMARY="$PROG"
DESC="$SUMMARY"

#all of the ips depends should be available from OmniTI repos

BUILD_DEPENDS_IPS="developer/sunstudio12.1 system/boot/wanboot system/boot/wanboot/internal developer/build/onbld system/library developer/versioning/git"

GIT=git

PKGSERVER=$PKGSRVR
PKGPREFIX=""
PREFIX=""
TMPDIR=/code
BUILDDIR=$PROG-$VER
CODEMGR_WS=$TMPDIR/$BUILDDIR/caiman

CAIMAN_CODEMGR_WS="CODEMGR\_WS=\/code\/$BUILDDIR\/caiman"
CAIMAN_PKG_REDIST="PKGPUBLISHER_REDIST=jeos.omniti.com; export PKGPUBLISHER_REDIST;"

sunstudio_location() {
    logmsg "Ensuring that Sun Studio is where Caiman thinks it is..."
    if [[ -d /opt/SUNWspro ]]; then
	logmsg "--- fake SUNWspro directory exists, good"
    else
	logmsg "--- making fake SUNWspro directory"
	logcmd mkdir -p /opt/SUNWspro || \
	    logerr "--- Error: failed to make directory"
    fi
    if [[ -L /opt/SUNWspro/sunstudio12.1 ]]; then
	logmsg "--- sunstudio12.1 link exists, good"
    else
	logmsg "--- soft-linking to /opt/sunstudio12.1"
        logcmd ln -s /opt/sunstudio12.1 /opt/SUNWspro/sunstudio12.1 || \
            logerr "--- Failed: ln -s /opt/sunstudio12.1/ /opt/SUNWspro"
    fi
}

#In order for the clone to work while running as root, you must have ssh'ed into the box with agent forwarding turned on.  Also the sudo'er file must either have the default, group, or user set to allow SSL_AUTH_SOCK.

clone_source(){
    logmsg "Creating build dir $TMPDIR/$BUILDDIR"
    logcmd mkdir $TMPDIR/$BUILDDIR
    logmsg "Entering $TMPDIR/$BUILDDIR"
    pushd $TMPDIR/$BUILDDIR > /dev/null 
    if [[ -d caiman ]]; then
        logmsg "Removing existing cloned repo"
        logcmd rm -rf caiman
    fi
    logmsg "Cloning OMNI caiman Source..."
    logcmd  $GIT clone src@src.omniti.com:~omni-os/core/caiman || \
        logerr "Failed to $GIT clone repo"
    logmsg "Leaving $TMPDIR/$BUILDDIR"
    popd > /dev/null 
}

modify_build_script() {
    logmsg "Entering $CODEMGR_WS"
    pushd $CODEMGR_WS > /dev/null
    logmsg "Changing omnios.sh variables to what we want them to be..."
    logcmd cp usr/src/tools/env/omnios.sh . || \
        logerr "Could not copy build environment"
    logcmd /usr/bin/gsed -i -e 's/^.*export CODEMGR_WS=.*/export '$CAIMAN_CODEMGR_WS'/g;' omnios.sh || \
        logerr "/usr/bin/gsed failed"
    logcmd `echo $CAIMAN_PKG_REDIST >> omnios.sh`
    logmsg "Leaving $CODEMGR_WS"
    popd > /dev/null

}

build_pkgs() {
    logmsg "Entering $CODEMGR_WS"
    pushd $CODEMGR_WS > /dev/null
    logmsg "Building caiman pkgs..."
    logcmd /opt/onbld/bin/nightly omnios.sh || logerr "Nighly failed"
    logmsg "Leaving $CODEMGR_WS"
    popd > /dev/null
}

push_pkgs() {
    logmsg "Entering $CODEMGR_WS"
    pushd $CODEMGR_WS > /dev/null
    logmsg "Pushing caiman pkgs to $PKGSERVER..."
    logcmd pkgrecv -s packages/i386/nightly-nd/repo.redist/ -d $PKGSERVER 'pkg:/*'
    logmsg "Leaving $CODEMGR_WS"
    popd > /dev/null
}

init
prep_build
sunstudio_location
clone_source
modify_build_script
build_pkgs
push_pkgs
clean_up