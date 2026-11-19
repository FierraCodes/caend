#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::shell::config {

class OsdConfig : public settings::ObjectNode {
    CONFIG_NODE(OsdConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, hideDelay, 2000)
    CONFIG_PROPERTY(bool, enableBrightness, true)
    CONFIG_PROPERTY(bool, enableMicrophone, false)
    // How long the caps/num lock pill stays up, in ms
    CONFIG_GLOBAL_PROPERTY(int, lockKeysHideDelay, 750)
};

} // namespace caelestia::shell::config
