//-----------------------------------------------------------------------------
// Asset
//-----------------------------------------------------------------------------

function RezAsset(id, attributes) {
  this.id = id;
  this.game_object_type = "asset";
  this.attributes = attributes;
  this.properties_to_archive = []; // ["type"];
  this.changed_attributes = [];
  if (!this.isTemplateObject()) {
    this.setAttribute("$type", this.assetType(), false);
  }
}

RezAsset.prototype = {
  __proto__: basic_object,
  constructor: RezAsset,

  elementInitializer() {},

  tag() {
    const type = this.getAttribute("$type");
    const generator = this.tagGenerators[type];
    if (generator) {
      return generator.call(this);
    } else {
      throw "No tag generator implementated for MIME type: " + type + "!";
    }
  },

  assetType() {
    const mime_type = this.getAttributeValue("$detected_mime_type");
    if (typeof mime_type == "undefined") {
      throw "No MIME information available for asset: " + this.id;
    }
    return mime_type.split("/")[0];
  },

  isImage() {
    return this.getAttribute("$type") == "image";
  },

  isAudio() {
    return this.getAttribute("$type") == "audio";
  },

  isVideo() {
    return this.getAttribute("$type") == "video";
  },

  isText() {
    return this.getAttribute("$type") == "text";
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

  tagGenerators: {
    image: function (asset) {
      return asset.imageTag();
    },
    audio: function (asset) {
      return asset.audioTag();
    },
    video: function (asset) {
      return asset.videoTag();
    },
  },
};

window.RezAsset = RezAsset;
