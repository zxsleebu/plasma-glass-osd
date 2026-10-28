#include "windowblur.h"
#include <KWindowEffects>
#include <QRegion>
#include <cmath>

void WindowBlur::enable(QWindow *window, const QRectF &rectF, qreal radius)
{
    if (!window) {
        return;
    }
    const QRect rect = rectF.toAlignedRect();
    if (rect.isEmpty()) {
        KWindowEffects::enableBlurBehind(window, false);
        return;
    }
    const int r = std::min<int>(std::lround(radius), std::min(rect.width(), rect.height()) / 2);
    // Build the rounded shape row by row in the corner zones
    QRegion region(rect.adjusted(0, r, 0, -r));
    for (int i = 0; i < r; ++i) {
        const double dy = r - i - 0.5;
        const int inset = int(std::lround(r - std::sqrt(r * r - dy * dy)));
        const int w = rect.width() - 2 * inset;
        region += QRect(rect.x() + inset, rect.y() + i, w, 1);
        region += QRect(rect.x() + inset, rect.bottom() - i, w, 1);
    }
    KWindowEffects::enableBlurBehind(window, true, region);
}

void WindowBlur::disable(QWindow *window)
{
    if (window) {
        KWindowEffects::enableBlurBehind(window, false);
    }
}
