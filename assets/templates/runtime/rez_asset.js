//-----------------------------------------------------------------------------
// Asset
//-----------------------------------------------------------------------------

let asset_proto = {
  __proto__: basic_object,

  elementInitializer() {
    this.type = this.assetType();
  },

  tag() {
    if(this.isImage()) {
      return this.imageTag();
    } else if(this.isAudio()) {
      return this.audioTag();
    } else if(this.isVideo()) {
      return this.videoTag();
    } else {
      throw "No tag implementation for MIME type: " + this.type + "!";
    }
  },

  assetType() {
    const mime_type = this.getAttributeValue("detected_mime_type");
    if(typeof(mime_type) == "undefined") {
      throw "No MIME information available for asset: " + this.id;
    }
    return mime_type.split("/")[0];
  },

  isImage() {
    return this.type == "image";
  },

  isAudio() {
    return this.type == "audio";
  },

  isVideo() {
    return this.type == "video";
  },

  isText() {
    return this.type == "text";
  },

  audioTag() {
    console.log("Audio tags not implemented");
    return "";
  },

  widthAttribute(w) {
    let width;
    if(typeof(w) == "undefined") {
      w = this.getAttribute("width");
      if(typeof(w) != undefined) {
        width = w;
      }
    } else {
      width = w;
    }

    return width ? " width=" + width.dq_wrap() : "";
  },

  heightAttribute(h) {
    let height;
    if(typeof(h) == "undefined") {
      h = this.getAttribute("height");
      if(typeof(h) != undefined) {
        height = h;
      }
    } else {
      height = h;
    }
    return height ? " height=" + height.dq_wrap() : "";
  },

  imageTag(w, h) {
    const id_str = this.id.dq_wrap();
    const path_str = this.path.dq_wrap();
    const tag = "<img asset-id=" + id_str + " src=" + path_str + this.widthAttribute(w) + this.heightAttribute(h) + ">";
    return tag;
  },

  videoTag() {
    console.log("Video tags not implemented");
    return "";
  }
};

function RezAsset(id, path, attributes) {
  this.id = id;
  this.game_object_type = "asset";
  this.path = path;
  this.attributes = attributes;
  this.type = this.assetType();
  this.properties_to_archive = ["type"];
  this.changed_attributes = [];
}

RezAsset.prototype = asset_proto;
RezAsset.prototype.constructor = RezAsset;
window.Rez.Asset = RezAsset;
