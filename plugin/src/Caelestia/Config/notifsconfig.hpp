#pragma once

#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

class NotifsConfig : public settings::ObjectNode {
    CONFIG_NODE(NotifsConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, expire, true)
    CONFIG_GLOBAL_ENUM_PROPERTY(NotifsFullscreen, fullscreen, NotifsFullscreen::On)
    CONFIG_GLOBAL_PROPERTY(int, defaultExpireTimeout, 5000)
    CONFIG_GLOBAL_PROPERTY(int, fullscreenExpireTimeout, 2000)
    CONFIG_PROPERTY(qreal, clearThreshold, 0.3)
    CONFIG_PROPERTY(int, expandThreshold, 20)
    CONFIG_GLOBAL_PROPERTY(bool, actionOnClick, false)
    CONFIG_PROPERTY(int, groupPreviewNum, 3)
    CONFIG_PROPERTY(bool, openExpanded, false)
    // "auto" (top right, bottom right with a bottom bar) or topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight
    CONFIG_GLOBAL_PROPERTY(QString, position, u"auto"_s)
    // Detached from the frame as a free-standing popup instead of growing out of the screen edge
    CONFIG_GLOBAL_PROPERTY(bool, floating, false)
};

} // namespace caelestia::shell::config
