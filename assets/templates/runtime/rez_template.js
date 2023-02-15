'use strict';

// const expr_pattern = /\$\{(^[^}]+)\}/g

const expr_pattern = /\$\{([a-z]+:\s*)?([^}]+)\}/g;

const template_proto = {
  tag_interpolate: function(expr, data) {
    const path = expr.split(/\./);
    return path.reduce((data, path_segment) => {
      if(data[path_segment]) {
        return data[path_segment];
      } else {
        throw "Cannot resolve " + path_segment + "!";
      }
    });
  },

  tagFunctionName: function(tag) {
    if(typeof(tag) == "undefined") {
      return "tag_interpolate";
    } else {
      return "tag_" + tag;
    }
  },

  tagFunction: function(tag) {
    const fn_name = this.tagFunctionName(tag);
    const fn = this[fn_name];
    if(typeof(fn) == "undefined") {
      throw "Unknown tag function: " + fn_name + "!";
    }
    return fn;
  },

  transform: function(data) {
    return this.source.replaceAll(expr_pattern, function(match, tag, expr) {
      const tag_fn = this.tagFunction(tag);
      return tag_fn(expr, data);
    });
  }
};

function RezTemplate(source, data = {}) {
  this.source = source;
  this.data = data;
}

RezTemplate.prototype = template_proto;
