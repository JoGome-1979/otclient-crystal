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
#ifdef ANDROID

#include "androidmanager.h"
#include <framework/global.h>
#include <framework/core/unzipper.h>
#include <framework/core/resourcemanager.h>
#include <framework/sound/soundmanager.h>

AndroidManager g_androidManager;

void AndroidManager::setAndroidApp(android_app* app) {
    m_app = app;
}

void AndroidManager::setAndroidManager(JNIEnv* env, jobject androidManager) {
    // This callback runs on Android's main thread, so its JNIEnv must be used
    // only here. The global reference intentionally lives until process exit:
    // deleting it from a static C++ destructor happens after GameActivity has
    // torn down the JVM bridge and causes a JNI cross-thread abort.
    jclass androidManagerJClass = env->GetObjectClass(androidManager);
    m_androidManagerJObject = env->NewGlobalRef(androidManager);
    m_midShowSoftKeyboard = env->GetMethodID(androidManagerJClass, "showSoftKeyboard", "()V");
    m_midHideSoftKeyboard = env->GetMethodID(androidManagerJClass, "hideSoftKeyboard", "()V");
    m_midGetDisplayDensity = env->GetMethodID(androidManagerJClass, "getDisplayDensity", "()F");
    m_midShowInputPreview = env->GetMethodID(androidManagerJClass, "showInputPreview", "(Ljava/lang/String;IIII)V");
    m_midUpdateInputPreview = env->GetMethodID(androidManagerJClass, "updateInputPreview", "(Ljava/lang/String;)V");
    m_midHideInputPreview = env->GetMethodID(androidManagerJClass, "hideInputPreview", "()V");
    m_midHideLoadingScreen = env->GetMethodID(androidManagerJClass, "hideLoadingScreen", "()V");
    m_midGetAppVersionCode = env->GetMethodID(androidManagerJClass, "getAppVersionCode", "()J");
    m_midRequestApkUpdate = env->GetMethodID(androidManagerJClass, "requestApkUpdate", "(Ljava/lang/String;Ljava/lang/String;J)V");
    m_midGetClipboardText = env->GetMethodID(androidManagerJClass, "getClipboardText", "()Ljava/lang/String;");
    m_midSetClipboardText = env->GetMethodID(androidManagerJClass, "setClipboardText", "(Ljava/lang/String;)V");
    env->DeleteLocalRef(androidManagerJClass);
}

void AndroidManager::showKeyboardSoft() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midShowSoftKeyboard);
}

void AndroidManager::hideKeyboard() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midHideSoftKeyboard);
}

namespace {
    jstring latin1ToJString(JNIEnv* env, const std::string& text) {
        std::u16string utf16;
        utf16.reserve(text.size());
        for (unsigned char c : text) {
            utf16.push_back(static_cast<char16_t>(c));
        }
        return env->NewString(reinterpret_cast<const jchar*>(utf16.data()), static_cast<jsize>(utf16.size()));
    }
}

void AndroidManager::showInputPreview(const std::string& text, int widgetX, int widgetY, int widgetW, int widgetH) {
    JNIEnv* env = getJNIEnv();
    jstring jText = latin1ToJString(env, text);
    env->CallVoidMethod(m_androidManagerJObject, m_midShowInputPreview, jText, (jint)widgetX, (jint)widgetY, (jint)widgetW, (jint)widgetH);
    env->DeleteLocalRef(jText);
}

void AndroidManager::updateInputPreview(const std::string& text) {
    JNIEnv* env = getJNIEnv();
    jstring jText = latin1ToJString(env, text);
    env->CallVoidMethod(m_androidManagerJObject, m_midUpdateInputPreview, jText);
    env->DeleteLocalRef(jText);
}

void AndroidManager::hideInputPreview() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midHideInputPreview);
}

void AndroidManager::hideLoadingScreen() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midHideLoadingScreen);
}

int64_t AndroidManager::getAppVersionCode() {
    JNIEnv* env = getJNIEnv();
    return static_cast<int64_t>(env->CallLongMethod(m_androidManagerJObject, m_midGetAppVersionCode));
}

void AndroidManager::requestApkUpdate(const std::string& url, const std::string& sha256, const int64_t versionCode) {
    JNIEnv* env = getJNIEnv();
    jstring jUrl = env->NewStringUTF(url.c_str());
    jstring jSha256 = env->NewStringUTF(sha256.c_str());
    env->CallVoidMethod(m_androidManagerJObject, m_midRequestApkUpdate, jUrl, jSha256, static_cast<jlong>(versionCode));
    env->DeleteLocalRef(jUrl);
    env->DeleteLocalRef(jSha256);
}

std::string AndroidManager::getClipboardText() {
    JNIEnv* env = getJNIEnv();
    auto jText = (jstring) env->CallObjectMethod(m_androidManagerJObject, m_midGetClipboardText);
    if (!jText) return "";
    std::string result = getStringFromJString(jText);
    env->DeleteLocalRef(jText);
    return result;
}

void AndroidManager::setClipboardText(const std::string& text) {
    JNIEnv* env = getJNIEnv();
    jstring jText = latin1ToJString(env, text);
    env->CallVoidMethod(m_androidManagerJObject, m_midSetClipboardText, jText);
    env->DeleteLocalRef(jText);
}

void AndroidManager::unZipAssetData() {
    std::string destFolder = getAppBaseDir() + "/game_data/";

    const std::filesystem::path initLua { destFolder + "init.lua" };
    if (std::filesystem::exists(initLua)) {
        return;
    }

    AAsset* dataAsset = AAssetManager_open(
            m_app->activity->assetManager,
            "data.zip",
            AASSET_MODE_BUFFER);

    if (!dataAsset) {
        g_logger.fatal("Failed to open data.zip from APK assets. Run setup_android_deps.sh to generate it.");
        return;
    }

    auto dataFileLength = AAsset_getLength(dataAsset);
    char* dataContent = (char *) malloc(dataFileLength + 1);
    AAsset_read(dataAsset, dataContent, dataFileLength);
    dataContent[dataFileLength] = '\0';

    unzipper::extract(dataContent, dataFileLength, destFolder);

    AAsset_close(dataAsset);
    free(dataContent);
}

std::string AndroidManager::getAppBaseDir() {
    return { m_app->activity->internalDataPath };
}

std::string AndroidManager::getStringFromJString(jstring text) {
    JNIEnv* env = getJNIEnv();

    const jchar* chars = env->GetStringChars(text, nullptr);
    const jsize length = env->GetStringLength(text);

    std::string result;
    result.reserve(length);

    for (jsize i = 0; i < length; ++i) {
        const jchar codePoint = chars[i];
        if (codePoint <= 0xFF) {
            result.push_back(static_cast<char>(codePoint));
        } else {
            // fallback for characters outside ISO-8859-1 range
            result.push_back('?');
        }
    }

    env->ReleaseStringChars(text, chars);

    return result;
}

float AndroidManager::getScreenDensity() {
    JNIEnv* jni = getJNIEnv();

    return jni->CallFloatMethod(m_androidManagerJObject, m_midGetDisplayDensity);
}

void AndroidManager::attachToAppMainThread() {
    getJNIEnv();
}

JNIEnv* AndroidManager::getJNIEnv() {
    JNIEnv *env;

    if (m_app->activity->vm->AttachCurrentThread(&env, nullptr) < 0) {
        g_logger.fatal("Failed to attach current thread");
        return nullptr;
    }

    return env;
}

/*
 * Java JNI functions
*/
extern "C" {

void Java_com_otclient_AndroidManager_nativeInit(JNIEnv* env, jobject androidManager) {
    g_androidManager.setAndroidManager(env, androidManager);
}

void Java_com_otclient_AndroidManager_nativeSetAudioEnabled(JNIEnv*, jobject, jboolean enabled) {
    g_sounds.setAudioEnabled(enabled);
}

}

#endif
