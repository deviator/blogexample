import vibe.d;

import std.exception;

shared static this()
{
    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];
    settings.sessionStore = new MemorySessionStore;
    settings.tlsContext = createTLSContext(TLSContextKind.server);
    settings.tlsContext.useCertificateChainFile("server.crt");
    settings.tlsContext.usePrivateKeyFile("server.key");

    auto router = new URLRouter;
    router.get("*", serveStaticFiles("public/"));
    router.registerWebInterface(new MyBlog);
    router.rebuild();

    listenHTTP(settings, router);
}

struct UserSettings
{
    bool loggedIn = false;
    string email;
}

struct Post
{
    string author;
    string title;
    string text;
}

class MyBlog
{
    mixin PrivateAccessProxy;
private:

    SessionVar!(UserSettings, "settings") userSettings;

public:
    Post[] posts;
    @path("/") void getHome(string _error)
    {
        auto error = _error;
        auto settings = userSettings;
        render!("index.dt", posts, settings, error);
    }

    @auth @errorDisplay!getHome void getWritepost(string _email, string _error)
    {
        auto email = _email;
        auto error = _error;
        render!("writepost.dt", email, error);
    }

    @auth @errorDisplay!getWritepost void postPosts(string title, string text, string _email)
    {
        posts ~= Post(_email, title, text);
        redirect("./");
    }

    @errorDisplay!getHome void postLogin(ValidEmail email, string pass)
    {
        enforce(pass == "secret", "Неверный пароль");
        userSettings = UserSettings(true, email);
        redirect("./");
    }

    void postLogout(scope HTTPServerResponse res)
    {
        userSettings = UserSettings.init;
        res.terminateSession();
        redirect("./");
    }

private:
    enum auth = before!ensureAuth("_email");

    string ensureAuth(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        if (!userSettings.loggedIn)
            redirect("/");
        return userSettings.email;
    }
}
