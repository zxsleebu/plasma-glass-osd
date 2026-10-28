#pragma once
#include <QObject>
#include <QRectF>
#include <QWindow>
#include <qqmlintegration.h>

// Requests compositor blur behind a rounded rectangle of a window
class WindowBlur : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    Q_INVOKABLE void enable(QWindow *window, const QRectF &rect, qreal radius);
    Q_INVOKABLE void disable(QWindow *window);
};
