//-----------------------------------------------------------------------------
// Asset
//-----------------------------------------------------------------------------

let asset_proto = {
  __proto__: basic_object,

  elementInitializer() {},

  tag() {
    if (this.isImage()) {
      return this.imageTag();
    } else if (this.isAudio()) {
      return this.audioTag();
    } else if (this.isVideo()) {
      return this.videoTag();
    } else {
      throw "No tag implementation for MIME type: " + this.type + "!";
    }
  },

  assetType() {
    const mime_type = this.getAttributeValue("detected_mime_type");
    if (typeof mime_type == "undefined") {
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

  getWidth(w) {
    if (typeof w != "undefined") {
      return w;
    }

    const width = this.getAttribute("width");
    if (typeof width != "undefined") {
      return width;
    }

    throw (
      "Asked for width of asset " +
      this.id +
      " which is not defined and no default was specified."
    );
  },

  getHeight(h) {
    if (typeof h != "undefined") {
      return h;
    }

    const height = this.getAttribute("height");
    if (typeof height != "undefined") {
      return height;
    }

    throw (
      "Asked for height of asset " +
      this.id +
      " which is not defined and no default was specified."
    );
  },

  imageElement(w, h) {
    const el = document.createElement("img");
    el.setAttribute("src", this.path);
    el.setAttribute("width", this.getWidth(w));
    el.setAttribute("height", this.getHeight(h));
    return el;
  },

  imageTag(w, h) {
    return this.imageElement(w, h).outerHTML;
  },

  videoTag() {
    console.log("Video tags not implemented");
    return "";
  },
};

function RezAsset(id, attributes) {
  this.id = id;
  this.game_object_type = "asset";
  this.attributes = attributes;
  if (!this.isTemplateObject()) {
    this.type = this.assetType();
  }
  this.properties_to_archive = ["type"];
  this.changed_attributes = [];
}

RezAsset.prototype = asset_proto;
RezAsset.prototype.constructor = RezAsset;
window.Rez.Asset = RezAsset;
