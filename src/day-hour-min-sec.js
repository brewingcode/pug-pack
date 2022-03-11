(function() {
    (function(root, factory) {
        if (typeof define === 'function' && define.amd) {
            return define([], factory);
        } else if (typeof module === 'object') {
            return module.exports = factory();
        } else {
            return root.dhms = factory();
        }
    })(this, function() {
        return function(t) {
            var d = Math.floor(t / (3600*24));
            var h = Math.floor(t % (3600*24) / 3600);
            var m = Math.floor(t % 3600 / 60);
            var s = Math.floor(t % 60);

            var out = '';

            if (d > 0) { out += d + 'd '; }
            if (h > 0) { out += h + 'h '; }
            if (m > 0) { out += m + 'm '; }
            if (s > 0) { out += s + 's '; }

            return out.replace(/\s+$/, '');
        }
    });
}).call(this);
