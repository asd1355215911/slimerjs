/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
"use strict";
var EXPORTED_SYMBOLS = ["slLauncher"];

const Cu = Components.utils;

Cu.import("resource://gre/modules/Services.jsm");
Cu.import('resource://slimerjs/addon-sdk/toolkit/loader.js'); //Sandbox, Require, main, Module, Loader

var sandbox = null;
var mainLoader = null;


var slLauncher = {
    launchMainScript: function (contentWindow, scriptFile) {
        sandbox = Cu.Sandbox(contentWindow,
                            {
                                'sandboxName': 'slimerjs',
                                'sandboxPrototype': contentWindow,
                                'wantXrays': true
                            });
        // expose a console object that dump output into the shell console
        var console = {
            debug:function(str) { dump(str+"\n");},
            log:function(str) { dump(str+"\n");},
            info:function(str) { dump(str+"\n");},
            warn:function(str) { dump(str+"\n");},
            error:function(str) { dump(str+"\n");},
            __exposedProps__ : {
                debug:'r', log:'r', info:'r', warn:'r',
                error:'r', trace:'r'
                /*clear:'r',
                dir:'r', dirxml:'r', group:'r', groupEnd:'r'*/
            }
        }
        sandbox.console = console;

        // import the slimer/phantom API into the sandbox
        Cu.import('resource://slimerjs/slimer.jsm', sandbox);
        Cu.import('resource://slimerjs/phantom.jsm', sandbox);

        // load and execute the provided script
        let fileURI = Services.io.newFileURI(scriptFile).spec;
        let dirURI =  Services.io.newFileURI(scriptFile.parent).spec;
        mainLoader = prepareLoader(fileURI, dirURI);

        try {
            Loader.main(mainLoader, 'main', sandbox);
        }
        catch(e) {
            this.processException(e, fileURI);
        }
    },

    processException : function (e, fileURI) {
        let msg;
        let stackRes = [];

        if (typeof e == 'object' && 'stack' in e) {
            msg = e.message;

            let r = /^\s*(.*)@(.*):(\d+)\s*$/gm;
            let m, a = [];
            // exemple of stack
            // bla@resource://slimerjs/addon-sdk/loader.jsm -> file:///home/laurent/projets/slimerjs/test/initial-tests.js:130
            // @resource://slimerjs/addon-sdk/loader.jsm -> file:///home/laurent/projets/slimerjs/test/initial-tests.js:134
            // evaluate@resource://slimerjs/addon-sdk/loader.jsm:180

            while ((m = r.exec(e.stack))) {
                let [full, funcName, sourceURL, lineNumber] = m;
                if (sourceURL.indexOf('->') != -1) {
                    sourceURL = sourceURL.split('->')[1].trim();
                }
                else if (sourceURL == 'resource://slimerjs/addon-sdk/toolkit/loader.js'
                         || sourceURL == 'resource://slimerjs/slLauncher.jsm' ) {
                    break;
                }

                var line = {
                    "sourceURL":sourceURL,
                    "line": lineNumber,
                    "function": funcName
                }
                stackRes.push(line);
            }
        }
        else {
            msg = e.toString();
            var line = {
                "sourceURL":fileURI,
                "line": 0,
                "function":null
            }
            stackRes.push(line);
        }
        if (sandbox.phantom.onError) {
            sandbox.phantom.onError(msg, stackRes);
        }
        else
            throw e;
    },

    injectJs : function (source, uri) {
        let sandbox = mainLoader.sandboxes[mainLoader.main.uri];

        let evalOptions =  {
          version : mainLoader.javascriptVersion,
          source: source
        }
        Loader.evaluate(sandbox, uri, evalOptions);
    },
    /**
     * the XUL elements containing all opened browsers
     * @var DOMElement
     */
    browserElements : null,

    /**
     * create a new browser element. call the given callback when it is ready,
     * with the browser element as parameter.
     */
    openBrowser : function(callback, currentNavigator) {
        let browser = currentNavigator;
        if (!currentNavigator) {
            browser = this.browserElements.ownerDocument.createElement("webpage");
        }
        function onReady(event) {
            browser.removeEventListener("BrowserReady", onReady, false);
            callback(browser);
        }
        browser.addEventListener("BrowserReady", onReady, false);
        if (!currentNavigator)
            this.browserElements.appendChild(browser);
        this.browserElements.selectedPanel = browser;
    },

    closeBrowser: function (navigator) {
        //navigator.resetBrowser();
        navigator.parentNode.removeChild(navigator);
        this.browserElements.selectedPanel = this.browserElements.lastChild;
    }
}


function prepareLoader(fileURI, dirURI) {

    return Loader.Loader({
        javascriptVersion : 'ECMAv5',

        paths: {
          'main': fileURI,
          '': dirURI,
          'sdk/': 'resource://slimerjs/addon-sdk/sdk/',
          'webpage' : 'resource://slimerjs/slimer-sdk/webpage'
        },
        globals: {
        },
        modules: {
          "webserver": Cu.import("resource://slimerjs/webserver.jsm", {}),
          "system": Cu.import("resource://slimerjs/system.jsm", {}),
        },
        resolve: function(id, requirer) {
            // we have some aliases, let's resolve them
            if (id == 'fs') {
                return 'sdk/io/file';
            }

            // the chrome module is only allowed in emmbedded modules
            if (id == 'chrome') {
                if (requirer.indexOf('sdk/') === 0
                    || requirer == "webpage") {
                    return 'chrome';
                }
                throw Error("Module "+ requirer+ " is not allowed to require the chrome module");
            }

            if (id.indexOf('@loader/') === 0)
                throw Error("Unknown "+ id +"module");

            // let's resolve other id module as usual
            let paths = id.split('/');
            let result = requirer.split('/');
            result.pop();
            while (paths.length) {
              let path = paths.shift();
              if (path === '..')
                result.pop();
              else if (path !== '.')
                result.push(path);
            }
            return result.join('/');
        }
    });
}
