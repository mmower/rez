//-----------------------------------------------------------------------------
// Game
//-----------------------------------------------------------------------------

/**
 * @class RezGame
 * @extends RezBasicObject
 * @description The central singleton that manages the entire game runtime. RezGame is
 * automatically instantiated with id "game" and is accessible globally via `$game`.
 *
 * RezGame provides:
 * - **Object Registry**: All game objects are registered here and accessible via `$()` or
 *   `getGameObject()`. Objects are indexed by tags and attributes for fast lookup.
 * - **Scene Management**: Controls scene transitions (`startSceneWithId`), interludes
 *   (`interludeSceneWithId`), and resumption (`resumePrevScene`) with a scene stack.
 * - **View System**: Manages the RezView that renders content to the DOM, including
 *   layout management and bound control updates.
 * - **Persistence**: Save/load functionality via `save()` and `load()` methods that
 *   serialize/deserialize all changed game object attributes.
 * - **Undo System**: Tracks attribute changes and object creation/deletion for undo support.
 * - **Flash Messages**: Temporary messages displayed on the next render cycle.
 * - **Systems**: Manages enabled RezSystem objects that hook into game events.
 *
 * The game is started by calling `start(containerId)` which initializes all objects,
 * builds the view, and starts the initial scene.
 */
class RezGame extends RezBasicObject {
  #containerId;
  #undoManager;
  #eventProcessor;
  #tagIndex;
  #attrIndex;
  #gameObjects;
  #view;

  constructor(id, attributes) {
    super("game", id, attributes);

    this.#undoManager = new RezUndoManager();
    this.#eventProcessor = new RezEventProcessor(this);
    this.#tagIndex = {};
    this.#attrIndex = {};
    this.#gameObjects = new Map();
    this.$ = this.getGameObject;
    this.addGameObject(this);
  }

  get undoManager() {
    return this.#undoManager;
  }

  get eventProcessor() {
    return this.#eventProcessor;
  }

  get gameObjects() {
    return this.#gameObjects;
  }

  get objectCount() {
    return this.#gameObjects.size;
  }

  get view() {
    return this.#view;
  }

  bindAs() {
    return "game";
  }

  getViewTemplate() {
    return this.$layout_template;
  }

  saveFileName(prefix) {
    if(typeof(prefix) === "undefined") {
      prefix = this.name;
    }
    const now = new Date();
    const formatter = (num) => {
      return String(num).padStart(2, "0");
    };
    const date_parts = [
      now.getFullYear() - 2000,
      now.getMonth() + 1,
      now.getDate(),
      now.getHours(),
      now.getMinutes(),
      now.getSeconds(),
    ];
    const dateMapped = date_parts.map(formatter);
    const dateJoined = dateMapped.join("");
    return prefix.toSnakeCase() + "_" + dateJoined + ".json";
  }

  dataArchive() {
    const archive = {};
    this.gameObjects.forEach((obj, id) => {obj.archiveInto(archive)});
    return archive;
  }

  gameArchive() {
    return {
      archive_format: this.archive_format,
      data: this.dataArchive()
    };
  }

  saveData() {
    return JSON.stringify(this.gameArchive());
  }

  get canSave() {
    return this.#view && this.#view.layoutStack.length == 0;
  }

   /**
   * @function save
   * @memberof RezGame#
   * @description triggers a download of the game archive
   *
   * This uses a hidden link with a 'download' attribute. The link is "clicked"
   * triggering the download of the JSON file. A timeout is used to remove the
   * link.
   */
  save() {
    if (!this.canSave) {
      throw new Error("Cannot save game at this time!");
    }

    this.getAll().forEach((obj) => {obj.runEvent("will_save")});

    const file = new File(
      [this.saveData()],
      this.saveFileName(this.getAttribute("name")),
      { type: "application/json" }
    );
    const link = document.createElement("a");
    link.style.display = "none";
    link.href = URL.createObjectURL(file);
    link.download = file.name;
    document.body.appendChild(link);
    link.click();
    setTimeout(() => {
      URL.revokeObjectURL(link.href);
      link.parentNode.removeChild(link);
    }, 0);
  }

  /**
   * @function load
   * @memberof RezGame#
   * @param {string} source JSON format source archive
   * @description given a JSON source archive restore the game state to what was archived.
   */
  load(source) {
    const wrapper = JSON.parse(source);

    const archiveFormat = wrapper["archive_format"];
    const currentFormat = this.getAttribute("archive_format");

    if(typeof archiveFormat === "undefined") {
      throw new Error("JSON does not represent a Rez game archive!");
    } else if(archiveFormat != currentFormat) {
      throw new Error(`JSON version v${archiveFormat} different to current v${currentFormat})!`);
    } else {
      console.log(`Matching archive format: ${archiveFormat}`);
    }

    const data = wrapper["data"];
    if(typeof data === "undefined") {
      throw new Error("JSON does not contain data archive!");
    } else {
      console.log("Found data");
    }

    // Load the game's attributes and properties
    for(const [id, obj_data] of Object.entries(data)) {
      console.log(`Loading data for ${id}`);
      const obj = this.getGameObject(id);
      obj.loadData(obj_data);
      obj.runEvent("did_load");
    }

    // Restore the game state
    this.runEvent("did_load");

    this.current_scene.resumeFromLoad();
    this.updateViewContent();
    this.updateView();
  }

  /**
   * @function getObjectsWithTag
   * @memberof RezGame#
   * @param {string} tag
   * @returns {array} array of indexed game-objects that have the specified tag
   * @description returns all game-objects tagged with the specified tag
   */
  getObjectsWithTag(tag) {
    const objects = this.#tagIndex[tag];
    if(objects) {
      return Array.from(objects);
    } else {
      return [];
    }
  }

  /**
   * For each attribute defined on this game object, add it to the game-wide
   * index for that attribute.
   * @TODO: Consider this may not work with mixed in properties as they do
   * not appear in #attributes
   *
   * @param {basic_object} elem element whose attributes are to be indexed
   */
  addToAttrIndex(elem) {
    if(!elem.isTemplateObject()) {
      Object.entries(elem.attributes).forEach(([k, v]) => {
        this.indexAttribute(elem.id, k);
      });
    }
  }

  removeFromAttrIndex(elem) {
    if(!elem.isTemplateObject()) {
      Object.entries(elem.attributes).forEach(([k, v]) => {
        this.unindexAttribute(elem.id, k);
      });
    }
  }

  /**
   * Adds the element to the per-attribute index.
   *
   * @param {string} elem_id id of element to add to the per-attr index
   * @param {string} attr_name
   */
  indexAttribute(elemId, attrName) {
    let index = this.#attrIndex[attrName] ?? new Set();
    index.add(elemId);
    this.#attrIndex[attrName] = index;
  }

  unindexAttribute(elemId, attrName) {
    let index = this.#attrIndex[attrName];
    if(index !== undefined) {
      index.delete(elemId);

      if(index.size === 0) {
        delete this.#attrIndex[attrName];
      } else {
        this.#attrIndex[attrName] = index;
      }
    }
  }

  /**
   * Return the ids of all game elements having the specified attribute.
   *
   * @function getObjectsWithAttr
   * @param {string} attr_name
   * @returns {Array} matching element ids
   */
  getObjectsWithAttr(attrName) {
    const index = this.#attrIndex[attrName] ?? new Set();
    return Array.from(index);
  }

  /**
   * @function indexObjectForTag
   * @memberof RezGame#
   * @param {object} obj reference to a game-object
   * @param {string} tag
   * @description applies the specified tag to the spectified game-object
   */
  indexObjectForTag(obj, tag) {
    let objects = this.#tagIndex[tag];
    if (!objects) {
      objects = new Set([obj.id]);
      this.#tagIndex[tag] = objects;
    } else {
      objects.add(obj.id)
    }
  }

  /**
   * @function unindexObjectForTag
   * @memberof RezGame#
   * @param {object} obj reference to a game-object
   * @param {string} tag a tag to remove
   * @description removes the specified tag from the specified game-object
   */
  unindexObjectForTag(obj, tag) {
    let objects = this.#tagIndex[tag];
    if(objects) {
      objects.delete(obj.id);

      if(objects.size === 0) {
        delete this.#tagIndex[tag];
      }
    }
  }

  /**
   * @function addToTagIndex
   * @memberof RezGame#
   * @param {object} obj game-object
   * @description indexes the specified game-object for all tags in it's tags attribute
   */
  addToTagIndex(obj) {
    const tags = obj.getAttributeValue("tags", new Set());
    tags.forEach((tag) => this.indexObjectForTag(obj, tag));
  }

  /**
   * @function removeFromTagIndex
   * @memberof RezGame#
   * @param {object} obj game-object
   * @description unindexes the specified object from all tags in its tags attribute
   */
  removeFromTagIndex(obj) {
    const tags = obj.getAttributeValue("tags", new Set());
    tags.forEach((tag) => this.unindexObjectForTag(obj, tag));
  }

  /**
   * @function addGameObject
   * @memberof RezGame#
   * @param {object} obj game-object
   * @description adds an object representing a game element to the game world and automatically tagging it by its attributes
  */
  addGameObject(obj) {
    if(!(obj instanceof RezBasicObject)) {
      throw new Error("Attempt to register non-game object!");
    }

    this.#gameObjects.set(obj.id, obj);
    this.addToTagIndex(obj);
    this.addToAttrIndex(obj);

    this.#undoManager?.recordNewElement(obj.id);

    return obj;
  }

  unmapObject(obj) {
    if(!(obj instanceof RezBasicObject)) {
      throw new Error("Attempt to unmap non-game object!");
    }

    obj.runEvent("unmap", {});

    if(this.#gameObjects.delete(obj.id)) {
      this.removeFromAttrIndex(obj);
      this.removeFromTagIndex(obj);
    }

    this.#undoManager?.recordRemoveElement(obj);
  }

  /**
   * @function getGameObject
   * @memberof RezGame#
   * @param {string|object} idOrRef either a string ID or a {$ref: "id"} object
   * @param {boolean} should_throw (default: true)
   * @returns {basic_object|undefined} game-object or undefined
   * @description given an element id returns the appropriate game-object reference
   *
   * Accepts both plain string IDs and {$ref: "id"} objects for backward compatibility.
   * If should_throw is true an exception will be thrown if the element id
   * is not valid. Otherwise null is returned.
   */
  getGameObject(idOrRef, shouldThrow = true) {
    const id = Rez.extractId(idOrRef);
    const obj = this.#gameObjects.get(id);
    if(typeof(obj) === "undefined") {
      if(shouldThrow) {
        throw new Error(`No such ID |${id}| found!`);
      } else {
        return undefined;
      }
    }
    return obj;
  }

  /**
   * @function getTypedGameObject
   * @memberof RezGame#
   * @param {string} id id of game-object
   * @param {string} type game object type (e.g. 'actor' or 'item')
   * @param {boolean} should_throw (default: true)
   * @returns {basic_object|null} game-object or null
   */
  getTypedGameObject(id, element, shouldThrow = true) {
    const obj = this.getGameObject(id, shouldThrow);
    if(typeof(obj) !== "undefined" && obj.element !== element) {
      if(shouldThrow) {
        throw new Error(`Game object |${id}| expected to be |${element}| but was |${obj.element}|!`);
      } else {
        return undefined;
      }
    }
    return obj;
  }

  /**
   * @function elementAttributeHasChanged
   * @memberof RezGame#
   * @param {object} elem reference to game-object
   * @param {string} attr_name name of the attribute whose value has changed
   * @param {*} old_value value of the attribute before the change
   * @param {*} new_value value of the attribute after the change
   * @description should be called whenever an attribute value is changed
   *
   * Currently this function notifies the undo manager and the view
   */
  elementAttributeHasChanged(elem, attrName, oldValue, newValue) {
    this.undoManager?.recordAttributeChange(elem.id, attrName, oldValue);

    if(this.#view) {
      this.#view.updateBoundControls(elem.id, attrName, newValue);
    }
  }

  /**
   * @function getRelationship
   * @memberof RezGame#
   * @param {string} source_id id of game-object that holds the relationship
   * @param {string} target_id id of game-object to which the relationship refers
   * @returns {RezRelationship|null} the relationship object for this relationship
   * @description we can cheat looking up a relationship because we know how their IDs
   * are constructed.
   *
   * Note that in Rez relationships are unidirectional so that getRelationship("a", "b")
   * and getRelationship("b", "a") are different RezRelationship objects.
   */
  getRelationship(sourceId, targetId) {
    const relId = "rel_" + sourceId + "_" + targetId;
    return this.getTypedGameObject(relId, "relationship", false);
  }

  getRelationshipsOf(sourceId) {
    return this.filterObjects(
      (o) => o.element == "relationship" && o.id.startsWith(`rel_${sourceId}_`)
    );
  }

  getRelationshipsOn(targetId) {
    return this.filterObjects(
      (o) => o.element == "relationship" && o.id.endsWith(`_${targetId}`)
    );
  }

  /**
   * @function filterObjects
   * @memberof RezGame#
   * @param {function} pred predicate to filter with
   * @returns {array} game-objects passing the filter
   * @description filters all game-objects returning those for which the pred filter returns true
   */
  filterObjects(pred) {
    return Array.from(this.#gameObjects.values()).filter(pred);
  }

  /**
   * @function getAll
   * @memberof RezGame#
   * @param {string} target_type (optional) a specific game object type (e.g. 'actor', 'item')
   * @returns {array} game-objects with the specified type
   * @description filters all game-objects returning those with the specified type
   */
  getAll(element) {
    if(typeof element === "undefined") {
      return Array.from(this.#gameObjects.values());
    } else {
      return this.filterObjects((obj) => obj.element === element);
    }
  }

  /**
   * @function startSceneWithId
   * @memberof RezGame#
   * @param {string} scene_id id of scene game-object
   * @param {object} params data to pass to the new scene
   * @description finish the current scene and start the new scene with the given id
   */
  startSceneWithId(sceneId, params = {}) {
    // current_scene is a Rez attribute defined by @scene

    if(this.current_scene) {
      this.runEvent("scene_did_end", {});
      this.current_scene.finish();
    }

    const scene = this.getTypedGameObject(sceneId, "scene", true);

    this.current_scene = scene;

    this.updateViewContent();

    this.clearFlashMessages();
    this.runEvent("scene_will_start", params);
    scene.start(params);
    scene.ready();
  }

  /**
   * @function interludeSceneWithId
   * @memberof RezGame#
   * @param {string} scene_id
   * @param {object} params data to pass to the new scene
   * @description interrupts the current scene, pushing it to the scene stack, and then starts the new scene with the given id
   */
  interludeSceneWithId(sceneId, params = {}) {
    // current_scene is a Rez attribute defined by @scene

    this.runEvent("scene_will_pause", {});
    this.pushScene();

    const scene = this.getTypedGameObject(sceneId, "scene", true);

    this.current_scene = scene;

    this.updateViewContent();

    this.clearFlashMessages();
    this.runEvent("scene_will_start", params);
    scene.start(params);
    scene.ready();
  }

  /**
   * @function resumePrevScene
   * @memberof RezGame#
   * @param {object} params data to pass back to the previous scene
   * @description finishes the current scene, then pops the previous scene from the scene stack and resumes it
   */
  resumePrevScene(params = {}) {
    if(!this.canResume()) {
      throw new Error("Cannot resume without a scene on the stack!");
    } else {
      // Let the interlude know we're done
      this.runEvent("scene_did_end", {});
      this.current_scene.finish();
      this.popScene(params);
      this.runEvent("scene_did_resume", {});

      const layout = this.current_scene.getViewLayout();
      // Merge any new params into the existing params
      layout.params = {...layout.params, ...params};
      this.updateView();

      // Fire ready on the card since its DOM is re-rendered
      if(this.current_scene.current_card) {
        this.current_scene.current_card.runEvent("ready", params);
      }
    }
  }

  get canUndo() {
    return this.#undoManager.canUndo;
  }

  undo() {
    if(this.canUndo) {
      this.#undoManager.undo();
    }
  }

  /**
   * Informs the view of new content to be rendered. It is left up to the view
   * & its layout to determine how this affects any existing content of the view.
   *
   * @memberof RezGame#
   * @param {Object} content block to be added to the view
   */
  setViewContent(content) {
    this.#view.addLayoutContent(content);
  }

  updateViewContent(params = {}) {
    const layout = this.current_scene.getViewLayout();
    layout.params = params;
    this.setViewContent(layout);
  }

  /**
   * @function updateView
   * @memberof RezGame#
   * @description re-renders the view calling 'will_render' and 'did_render'
   * event handlers on both game and current scene
   */
  updateView() {
    this.runEvent("will_render", {});
    this.current_scene?.runEvent("will_render", {});
    this.#view.update();
    this.current_scene?.runEvent("did_render", {});
    this.runEvent("did_render", {});
    this.clearFlashMessages();
  }

  restoreView(view) {
    this.#view = view;
    this.updateView();
  }

  /**
   * @function canResume
   * @memberof RezGame#
   * @returns {boolean}
   * @description returns true if there is at least one scene in the scene stack
   */
  canResume() {
    return this.$scene_stack.length > 0;
  }

  /**
   * @function pushScene
   * @memberof RezGame#
   * @description interrupts the current scene and puts it on the scene stack
   */
  pushScene() {
    // current_scene is an attribute defined on @game
    this.current_scene.interrupt();
    this.$scene_stack.push(this.current_scene_id);
    this.#view.pushLayout(new RezSingleLayout("scene", this));
  }

  /**
   * @function popScene
   * @memberof RezGame#
   * @param {object} params data to be passed to the scene being resumed
   * @description removes the top object of the scene stack and makes it the current scene
   */
  popScene(params = {}) {
    this.#view.popLayout();
    this.current_scene_id = this.$scene_stack.pop();
    this.current_scene.resume(params);
  }

  /**
   * @function setViewLayout
   * @memberof RezGame#
   * @param {*} layout ???
   * @description ???
   */
  setViewLayout(layout) {
    this.#view.setLayout(layout);
  }

  /**
   * @function start
   * @memberof RezGame#
   * @param {string} container_id id of the HTML element into which game content is rendered
   * @description called automatically from the index.html this runs init on the registered game
   * objects then starts the view and starts the initial scene
   */
  start(containerId) {
    console.log("> Game.start");

    this.#containerId = containerId;

    // Initialize the game objects starting with #game
    this.init();
    const game_objects = this.getAttribute("$init_order");
    game_objects.forEach(function (obj_id) {
      const obj = this.getGameObject(obj_id);
      obj.init();
    }, this);

    // Now everything is guaranteed to be initialized, give
    // each object a chance to respond to the game being about
    // to start
    this.getAll().forEach((obj) => {
      obj.runEvent("game_did_start", {})
    });

    // Give the game a last chance to do something before we
    // start painting the view
    this.runEvent("ready", {});

    this.buildView();
    this.startSceneWithId(this.initial_scene_id);
  }

  /**
   * Assigns the #view private attribute with a RezView that is initialized
   * with a single layout.
   */
  buildView() {
    this.#view = new RezView(
      this.#containerId,
      this.#eventProcessor,
      new RezSingleLayout("game", this)
    );
  }

  /**
   * @function getEnabledSystems
   * @memberof RezGame#
   * @returns {array} all 'system' game-objects with attribute enabled=true
   */
  getEnabledSystems() {
    const filter = (o) => o.element === "system" && o.getAttributeValue("enabled");
    const order = (sys_a, sys_b) => sys_b.getAttributeValue("priority") - sys_a.getAttributeValue("priority");
    return this.filterObjects(filter).sort(order);
  }

  /**
   * @function addFlashMessage
   * @memberof RezGame#
   * @param {string} message
   * @description adds the given message to the flash to be displayed on the next render
   */
  addFlashMessage(message) {
    this.$flash_messages.push(message);
  }

  /**
   * @function clearFlashMessages
   * @memberof RezGame#
   * @description empties the flash messages
   */
  clearFlashMessages() {
    this.$flash_messages = [];
  }
}

window.Rez.RezGame = RezGame;
