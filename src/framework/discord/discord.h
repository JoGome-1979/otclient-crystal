/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
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

#include <framework/config.h>
#include <string>

#ifndef ANDROID
#if ENABLE_DISCORD_RPC == 1
#include <discord_register.h>
#include <discord_rpc.h>

class Discord
{
public:
    void init(std::function<bool()>& canUpdate, std::function<void(std::string&)>& onUpdate);

    std::string getIdentityApplicationId() { return RPC_API_KEY; }
    bool requestIdentityAuthorization(const std::string& redirectUri) { return Discord_RequestIdentityAuthorization(redirectUri.c_str()) != 0; }
    int getIdentityState() { return Discord_GetIdentityState(); }
    int getIdentityErrorCode() { return Discord_GetIdentityErrorCode(); }
    std::string getIdentityUserId() { char value[32]{}; Discord_GetIdentityUserId(value, sizeof(value)); return value; }
    std::string takeIdentityCode() { char value[1024]{}; Discord_TakeIdentityCode(value, sizeof(value)); return value; }
    void cancelIdentityAuthorization() { Discord_CancelIdentityAuthorization(); }

private:
    void update();

    std::function<bool()> m_canUpdate;
    std::function<void(std::string&)> m_onUpdate;
};

extern Discord g_discord;
#endif
#endif
