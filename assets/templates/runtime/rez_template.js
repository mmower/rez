'use strict';

const expr_pattern = /\$\{(^[^}]+)\}/g

const template_proto = {
  transform: function(data) {
    return this.source.replaceAll(expr_pattern, function(match, expr) {
      const path = expr.split(/\./);
      return path.reduce((data, path_segment) => {
        if(data[path_segment]) {

        }
      });
    });
  }
};

function RezTemplate(source) {
  this.source = source;
}

RezTemplate.prototype = template_proto;
