/*
 * Copyright (c) 2010-2014 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#pragma once

#ifdef ANDROID

#include <game-activity/native_app_glue/android_native_app_glue.h>
#include <cstdint>
#include <string>

class AndroidManager {
public:
    void setAndroidApp(android_app*);
    void setAndroidManager(JNIEnv*, jobject);

    void showKeyboardSoft();
    void hideKeyboard();

    // Input preview toolbar: positioned near the focused widget
    void showInputPreview(const std::string& text, int widgetX = -1, int widgetY = -1, int widgetW = -1, int widgetH = -1);
    void updateInputPreview(const std::string& text);
    void hideInputPreview();
    // Hides the Android loading overlay after the Lua UI is ready to draw.
    void hideLoadingScreen();

    // Returns Android's monotonically increasing package version used by the
    // updater to decide whether a new APK must be offered.
    int64_t getAppVersionCode();

    // Hands a verified HTTPS package description to the Java/Kotlin layer,
    // which downloads, validates and opens Android's package installer.
    void requestApkUpdate(const std::string& url, const std::string& sha256, int64_t versionCode);

    void unZipAssetData();

    std::string getClipboardText();
    void setClipboardText(const std::string& text);

    std::string getStringFromJString(jstring);
    std::string getAppBaseDir();

    float getScreenDensity();

    void attachToAppMainThread();
private:
    JNIEnv* getJNIEnv();

    android_app* m_app{ nullptr };
    jobject m_androidManagerJObject{ nullptr };
    jmethodID m_midShowSoftKeyboard{ nullptr };
    jmethodID m_midHideSoftKeyboard{ nullptr };
    jmethodID m_midGetDisplayDensity{ nullptr };
    jmethodID m_midShowInputPreview{ nullptr };
    jmethodID m_midUpdateInputPreview{ nullptr };
    jmethodID m_midHideInputPreview{ nullptr };
    jmethodID m_midHideLoadingScreen{ nullptr };
    jmethodID m_midGetAppVersionCode{ nullptr };
    jmethodID m_midRequestApkUpdate{ nullptr };
    jmethodID m_midGetClipboardText{ nullptr };
    jmethodID m_midSetClipboardText{ nullptr };
};

extern AndroidManager g_androidManager;

#endif
