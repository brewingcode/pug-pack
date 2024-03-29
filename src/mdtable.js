// https://github.com/wooorm/markdown-table

(function(root, factory) {
  if (typeof define === 'function' && define.amd) {
    return define([], factory);
  } else if (typeof module === 'object') {
    return module.exports = factory();
  } else {
    return root.mdtable = factory();
  }
})(this, function() {
  return function(table, options) {
    function _typeof(obj) { if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") { _typeof = function _typeof(obj) { return typeof obj; }; } else { _typeof = function _typeof(obj) { return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj; }; } return _typeof(obj); }

    var repeat = function(s, n) {
      var result = '';
      for (var i = 1; i <= n; i++) {
        result += s;
      }
      return result;
    };

    var serialize = function(value) {
      return value === null || value === undefined ? '' : String(value);
    }

    var defaultStringLength = function(value) {
      return value.length;
    }

    var toAlignment = function(value) {
      var code = typeof value === 'string' ? value.charCodeAt(0) : x;
      return code === L || code === l ? l : code === R || code === r ? r : code === C || code === c ? c : x;
    }

    var trailingWhitespace = / +$/; // Characters.

    var space = ' ';
    var lineFeed = '\n';
    var dash = '-';
    var colon = ':';
    var verticalBar = '|';
    var x = 0;
    var C = 67;
    var L = 76;
    var R = 82;
    var c = 99;
    var l = 108;
    var r = 114; // Create a table from a matrix of strings.

    var string = (function() {
      var settings = options || {};
      var padding = settings.padding !== false;
      var start = settings.delimiterStart !== false;
      var end = settings.delimiterEnd !== false;
      var align = settings.align || [];
      align = typeof align === 'string' ? align.split('') : align.concat();
      var alignDelimiters = settings.alignDelimiters !== false;
      var alignments = [];
      var stringLength = settings.stringLength || defaultStringLength;
      var rowIndex = -1;
      var rowLength = table.length;
      var cellMatrix = [];
      var sizeMatrix = [];
      var row = [];
      var sizes = [];
      var longestCellByColumn = [];
      var mostCellsPerRow = 0;
      var cells;
      var columnIndex;
      var columnLength;
      var largest;
      var size;
      var cell;
      var lines;
      var line;
      var before;
      var after;
      var code; // This is a superfluous loop if we don’t align delimiters, but otherwise we’d
      // do superfluous work when aligning, so optimize for aligning.

      while (++rowIndex < rowLength) {
        cells = table[rowIndex];
        columnIndex = -1;
        columnLength = cells.length;
        row = [];
        sizes = [];

        if (columnLength > mostCellsPerRow) {
          mostCellsPerRow = columnLength;
        }

        while (++columnIndex < columnLength) {
          cell = serialize(cells[columnIndex]);

          if (alignDelimiters === true) {
            size = stringLength(cell);
            sizes[columnIndex] = size;
            largest = longestCellByColumn[columnIndex];

            if (largest === undefined || size > largest) {
              longestCellByColumn[columnIndex] = size;
            }
          }

          row.push(cell);
        }

        cellMatrix[rowIndex] = row;
        sizeMatrix[rowIndex] = sizes;
      } // Figure out which alignments to use.


      columnIndex = -1;
      columnLength = mostCellsPerRow;

      if (_typeof(align) === 'object' && 'length' in align) {
        while (++columnIndex < columnLength) {
          alignments[columnIndex] = toAlignment(align[columnIndex]);
        }
      } else {
        code = toAlignment(align);

        while (++columnIndex < columnLength) {
          alignments[columnIndex] = code;
        }
      } // Calculate the alignment row.


      columnIndex = -1;
      columnLength = mostCellsPerRow;
      row = [];
      sizes = [];

      while (++columnIndex < columnLength) {
        code = alignments[columnIndex];
        before = '';
        after = '';

        if (code === l) {
          before = colon;
        } else if (code === r) {
          after = colon;
        } else if (code === c) {
          before = colon;
          after = colon;
        } // There *must* be at least one hyphen-minus in each alignment cell.


        size = alignDelimiters ? Math.max(1, longestCellByColumn[columnIndex] - before.length - after.length) : 1;
        cell = before + repeat(dash, size) + after;

        if (alignDelimiters === true) {
          size = before.length + size + after.length;

          if (size > longestCellByColumn[columnIndex]) {
            longestCellByColumn[columnIndex] = size;
          }

          sizes[columnIndex] = size;
        }

        row[columnIndex] = cell;
      } // Inject the alignment row.

      if (!settings.noAlign) {
        cellMatrix.splice(1, 0, row);
        sizeMatrix.splice(1, 0, sizes);
      }

      rowIndex = -1;
      rowLength = cellMatrix.length;
      lines = [];

      while (++rowIndex < rowLength) {
        row = cellMatrix[rowIndex];
        sizes = sizeMatrix[rowIndex];
        columnIndex = -1;
        columnLength = mostCellsPerRow;
        line = [];

        if ( (settings.noalign || settings.plaintext) && rowIndex == 1) {
          continue;
        }

        while (++columnIndex < columnLength) {
          cell = row[columnIndex] || '';
          before = '';
          after = '';

          if (alignDelimiters === true) {
            size = longestCellByColumn[columnIndex] - (sizes[columnIndex] || 0);
            code = alignments[columnIndex];

            if (code === r) {
              before = repeat(space, size);
            } else if (code === c) {
              if (size % 2 === 0) {
                before = repeat(space, size / 2);
                after = before;
              } else {
                before = repeat(space, size / 2 + 0.5);
                after = repeat(space, size / 2 - 0.5);
              }
            } else {
              after = repeat(space, size);
            }
          }

          if (start === true && columnIndex === 0) {
            line.push(verticalBar);
          }

          if (padding === true && // Don’t add the opening space if we’re not aligning and the cell is
          // empty: there will be a closing space.
          !(alignDelimiters === false && cell === '') && (start === true || columnIndex !== 0)) {
            line.push(space);
          }

          if (alignDelimiters === true) {
            line.push(before);
          }

          line.push(cell);

          if (alignDelimiters === true) {
            line.push(after);
          }

          if (padding === true) {
            line.push(space);
          }

          if (end === true || columnIndex !== columnLength - 1) {
            line.push(verticalBar);
          }
        }

        if (settings.plaintext) {
          line = line.filter(function(cell) { return cell !== verticalBar })
        }

        line = line.join('');

        if (end === false) {
          line = line.replace(trailingWhitespace, '');
        }

        if (settings.stream) {
          settings.stream.write(line + lineFeed)
        }
        else {
          lines.push(line);
        }
      }

      return settings.stream ? undefined : lines.join(lineFeed);
    })();

    return string;
  };
});
