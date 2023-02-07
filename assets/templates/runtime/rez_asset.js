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

  getDimensions() {
    const w = this.getAttribute("width");
    const h = this.getAttribute("height");

    if(w && h) {
      return "width: " + w + "; height: " + h;
    } else if(w) {
      return "width: " + w;
    } else if(h) {
      return "height: " + h;
    } else {
      return "";
    }
  },

  audioTag() {
    console.log("Audio tags not implemented");
    return "";
  },

  imageTag() {
    const style = this.getDimensions();
    return new Handlebars.SafeString("<img src='" + this.path + "' style='" + style + "' />");
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
