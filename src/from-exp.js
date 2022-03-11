(function() {
    (function(root, factory) {
        if (typeof define === 'function' && define.amd) {
            return define([], factory);
        } else if (typeof module === 'object') {
            return module.exports = factory();
        } else {
            return root.fromExp = factory();
        }
    })(this, function() {
        // https://github.com/shrpne/from-exponential
        // ...install, minify, beautify, prune
        function r(r) {
            return Array.isArray(r) ? r : String(r).split(/[eE]/);
        }
        return function(e) {
            const t = r(e);
            if (! function(e) {
                    const t = r(e);
                    return !Number.isNaN(Number(t[1]));
                }(t)) return t[0];
            let n = "-" === t[0][0] ? "-" : "", u = t[0].replace(/^-/, "").split("."), i = u[0], f = u[1] || "", o = Number(t[1]);
            if (0 === o) return n + i + "." + f;
            if (o < 0) {
                const s = i.length + o;
                if (s > 0) return n + i.substr(0, s) + "." + i.substr(s) + f;
                let a = "0.";
                for (o += 1; o;) a += "0", o += 1;
                return n + a + i + f;
            }
            const c = f.length - o;
            if (c > 0) {
                const p = f.substr(o);
                return n + i + f.substr(0, o) + "." + p;
            }
            for (var b = -c, d = ""; b;) d += "0", b -= 1;
            return n + i + f + d;
        };
    });
}).call(this);
