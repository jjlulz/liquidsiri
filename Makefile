export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidSiri
LiquidSiri_FILES = Tweak.xm
LiquidSiri_CFLAGS = -fobjc-arc
LiquidSiri_FRAMEWORKS = UIKit QuartzCore CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
