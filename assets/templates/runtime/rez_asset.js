//-----------------------------------------------------------------------------
// Asset
//-----------------------------------------------------------------------------

class RezAsset extends RezBasicObject {
  constructor(id, attributes) {
    super("asset", id, attributes);
  }

  get assetType() {
    const mime_type = this.getAttributeValue("$detected_mime_type");
    if (typeof mime_type == "undefined") {
      throw new Error(`No MIME information available for asset: ${this.id}`);
    }
    return mime_type.split("/")[0];
  }

  isImage() {
    return this.assetType === "image";
  }

  isAudio() {
    return this.assetType === "audio";
  }

  isVideo() {
    return this.assetType === "video";
  }

  isText() {
    return this.assetType === "text";
  }

  audioTag() {
    throw new Error(`Audio tags not implemented |${this.id})|`);
  }

  getWidth(w) {
    if (typeof w != "undefined") {
      return w;
    }

    const width = this.getAttribute("width");
    if (typeof width != "undefined") {
      return width;
    }

    throw new Error(`Asked for width of asset |${this.id}| which is not defined and no default was specified.`);
  }

  getHeight(h) {
    if (typeof h != "undefined") {
      return h;
    }

    const height = this.getAttribute("height");
    if (typeof height != "undefined") {
      return height;
    }

    throw new Error(`Asked for height of asset ${this.id} which is not defined and no default was specified.`);
  }

  imageElement(w, h) {
    const el = document.createElement("img");
    el.setAttribute("src", this.$dist_path);
    el.setAttribute("width", this.getWidth(w));
    el.setAttribute("height", this.getHeight(h));
    return el;
  }

  imageTag(w, h) {
    return this.imageElement(w, h).outerHTML;
  }

  videoTag() {
    throw new Error(`Video tags not implemented |${this.id}|`);
  }
}

window.Rez.RezAsset = RezAsset;
