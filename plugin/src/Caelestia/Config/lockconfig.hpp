#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

class LockConfig : public settings::ObjectNode {
    CONFIG_NODE(LockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, useWallpaper, false)
    CONFIG_PROPERTY(bool, recolourLogo, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableFprint, true)
    CONFIG_GLOBAL_PROPERTY(int, maxFprintTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, enableFaceAuth, true)
    CONFIG_GLOBAL_ENUM_PROPERTY(FaceAuthProvider, faceAuthProvider, FaceAuthProvider::Howdy)
    CONFIG_GLOBAL_PROPERTY(int, maxFaceAuthTries, 3)
    CONFIG_GLOBAL_PROPERTY(bool, triggerFaceAuthOnWake, true)
    CONFIG_PROPERTY(bool, hideNotifs, false)
    CONFIG_GLOBAL_PROPERTY(bool, enableSessionControls, false)
    // end4: the lock screen's power buttons only arm an action, which runs after the password is accepted
    CONFIG_GLOBAL_PROPERTY(bool, requirePasswordToPower, false)
    // From end4: unlock the GNOME login keyring with the password used to unlock the screen
    CONFIG_GLOBAL_PROPERTY(bool, unlockKeyring, true)
    CONFIG_GLOBAL_PROPERTY(bool, lockOnStartup, false)
};

} // namespace caelestia::shell::config
