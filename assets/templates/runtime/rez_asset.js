//-----------------------------------------------------------------------------
// Asset
//-----------------------------------------------------------------------------

/**
 * @class RezAsset
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a media asset in the Rez game engine. Assets can be images, audio, video,
 * or text files. Provides methods for determining asset type and generating HTML elements for display.
 * Asset MIME types are detected during compilation and stored in the $detected_mime_type attribute.
 */
class RezAsset extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezAsset
   * @param {string} id - unique identifier for this asset
   * @param {object} attributes - asset attributes from Rez compilation including file path and MIME type
   * @description Creates a new asset instance
   */
  constructor(id, attributes) {
    super("asset", id, attributes);
  }

  /**
   * @function assetType
   * @memberof RezAsset
   * @returns {string} the primary asset type (e.g., "image", "audio", "video", "text")
   * @description Returns the primary MIME type category for this asset
   * @throws {Error} if no MIME type information is available
   */
  get assetType() {
    const mime_type = this.getAttributeValue("$detected_mime_type");
    if (typeof mime_type == "undefined") {
      throw new Error(`No MIME information available for asset: ${this.id}`);
    }
    return mime_type.split("/")[0];
  }

  /**
   * @function isImage
   * @memberof RezAsset
   * @returns {boolean} true if this asset is an image
   * @description Determines if this asset is an image file
   */
  isImage() {
    return this.assetType === "image";
  }

  /**
   * @function isAudio
   * @memberof RezAsset
   * @returns {boolean} true if this asset is an audio file
   * @description Determines if this asset is an audio file
   */
  isAudio() {
    return this.assetType === "audio";
  }

  /**
   * @function isVideo
   * @memberof RezAsset
   * @returns {boolean} true if this asset is a video file
   * @description Determines if this asset is a video file
   */
  isVideo() {
    return this.assetType === "video";
  }

  /**
   * @function isText
   * @memberof RezAsset
   * @returns {boolean} true if this asset is a text file
   * @description Determines if this asset is a text file
   */
  isText() {
    return this.assetType === "text";
  }

  /**
   * @function audioTag
   * @memberof RezAsset
   * @throws {Error} audio tags are not yet implemented
   * @description Placeholder for generating HTML audio tags (not yet implemented)
   */
  audioTag() {
    throw new Error(`Audio tags not implemented |${this.id})|`);
  }

  /**
   * @function getWidth
   * @memberof RezAsset
   * @param {number} w - optional width override
   * @returns {number} the width to use for this asset
   * @description Gets the width for this asset, using the provided override if available,
   * falling back to the asset's width attribute.
   * @throws {Error} if no width is specified and no default is provided
   */
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

  /**
   * @function getHeight
   * @memberof RezAsset
   * @param {number} h - optional height override
   * @returns {number} the height to use for this asset
   * @description Gets the height for this asset, using the provided override if available,
   * falling back to the asset's height attribute.
   * @throws {Error} if no height is specified and no default is provided
   */
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

  /**
   * @function imageElement
   * @memberof RezAsset
   * @param {number} w - optional width override
   * @param {number} h - optional height override
   * @returns {HTMLImageElement} an HTML image element configured for this asset
   * @description Creates an HTML image element for this asset with the specified or default dimensions
   */
  imageElement(w, h) {
    const el = document.createElement("img");
    el.setAttribute("src", this.$dist_path);
    el.setAttribute("width", this.getWidth(w));
    el.setAttribute("height", this.getHeight(h));
    return el;
  }

  /**
   * @function imageTag
   * @memberof RezAsset
   * @param {number} w - optional width override
   * @param {number} h - optional height override
   * @returns {string} HTML image tag as a string
   * @description Generates an HTML image tag string for this asset with specified or default dimensions
   */
  imageTag(w, h) {
    return this.imageElement(w, h).outerHTML;
  }

  /**
   * @function videoTag
   * @memberof RezAsset
   * @throws {Error} video tags are not yet implemented
   * @description Placeholder for generating HTML video tags (not yet implemented)
   */
  videoTag() {
    throw new Error(`Video tags not implemented |${this.id}|`);
  }
}

window.Rez.RezAsset = RezAsset;
