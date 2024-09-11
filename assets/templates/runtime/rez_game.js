//-----------------------------------------------------------------------------
// Game
//-----------------------------------------------------------------------------

/**
 * @class
 * @param {string} id
 * @param {object} attributes
 * @description Represents the singleton @game instance
 */
function RezGame(id, attributes) {
  this.id = id;
  this.undo_manager = new RezUndoManager();
  this.event_processor = new RezEventProcessor(this);
  this.game_object_type = "game";
  this.attributes = attributes;
  this.tag_index = {};
  this.attr_index = {};
  this.wmem = { game: this };
  this.game_objects = new Map();
  this.properties_to_archive = [
    "wmem",
    "tag_index",
    "attr_index"
  ];
  this.changed_attributes = [];
  this.$ = this.getGameObject;
  this.addGameObject(this);
}

RezGame.prototype = {
  __proto__: basic_object,
  constructor: RezGame,

  targetType: "game",

  /**
   * @memberof RezGame
   * @property {RezUndoManager} undoManager the game undo manager
   */
  get undoManager() {
    return this.undo_manager;
  },

  /**
   * @function bindAs
   * @memberof RezGame
   * @returns {string} default binding name for this object
   */
  bindAs() {
    return "game";
  },

  /**
   * @function getViewTemplate
   * @memberof RezGame
   * @returns {*} the layout template object, need to check what type that is
   */
  getViewTemplate() {
    return this.$layout_template;
  },

  /**
   * @function initLevels
   * @memberof RezGame
   * @returns {Array} array of init levels to run (e.g. [0, 1, ..])
   */
  initLevels() {
    return [0, 1, 2, 3];
  },

  /**
   * @function saveFileName
   * @memberof RezGame
   * @param {string} prefix (defaults to game name)
   * @returns {string} file name
   * @description generates a save file name using a prefix & a date-time with
   * a .json extension.
   */
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
      now.getMonth(),
      now.getDate(),
      now.getHours(),
      now.getMinutes(),
      now.getSeconds(),
    ];
    const date_mapped = date_parts.map(formatter);
    const date_joined = date_mapped.join("");
    return prefix.toSnakeCase() + "_" + date_joined + ".json";
  },

  /**
   * @function dataWithArchivedObjects
   * @memberof RezGame
   * @param {object} data data archive to append objects to
   * @returns {object} modified data archive
   */
  dataWithArchivedObjects(data) {
    console.dir(this);
    console.log("Checking " + this.game_objects.size + " objects.");
    this.game_objects.forEach(function (obj, id) {
      console.log(id + " -> " + obj.needsArchiving());
      if (obj.needsArchiving()) {
        data["objs"] = data["objs"] || {};
        data["objs"][obj.id] = obj;
      }
    });
    console.log("Done");
    return data;
  },

  /**
   * @function toJSON
   * @memberof RezGame
   * @returns {object} a versioned JSON archive
   */
  toJSON() {
    let data = this.archiveDataContainer();
    data = this.dataWithArchivedAttributes(data);
    data = this.dataWithArchivedProperties(data);
    data = this.dataWithArchivedObjects(data);

    return {
      rez_archive: this.archive_format,
      data: data,
    };
  },

  /**
   * @function archive
   * @memberof RezGame
   * @returns {string} JSON formatted archive string
   */
  archive() {
    const archived = {};

    return JSON.stringify(this, function (key, value) {
      console.log("archive: [" + key + "]");

      if (key == "" || value == null) {
        // This is the game itself
        archived["game"] = true;
        return value;
      } else if (isGameObject(value)) {
        // This is a game object
        const goid = value.id; // GameObjectID
        console.log("<- is a game object: " + goid);
        if (archived[goid]) {
          console.log("<- is already archived");
          return {
            json$safe: true,
            type: "ref",
            game_object_type: value.game_object_type,
            game_object_id: value.id,
          };
        } else {
          console.log("<- archived");
          archived[goid] = true;
          return value;
        }
      } else if (isObject(value)) {
        return value.obj_map((v) => {
          if (isGameObject(v)) {
            return {
              json$safe: true,
              type: "ref",
              game_object_type: value.game_object_type,
              game_object_id: value.id,
            };
          } else {
            return v;
          }
        });
      } else if (typeof value == "function") {
        return {
          json$safe: true,
          type: "function",
          value: value.toString(),
        };
      } else {
        console.log("<- value:" + value);
        return value;
      }
      return value;
    });
  },

  /**
   * @function save
   * @memberof RezGame
   * @description triggers a download of the game archive
   *
   * This uses a hidden link with a 'download' attribute. The link is "clicked"
   * triggering the download of the JSON file. A timeout is used to remove the
   * link.
   */
  save() {
    this.getAll().forEach((obj) => {obj.runEvent("save_game")});

    const file = new File(
      [this.archive()],
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
  },

  /**
   * @function load
   * @memberof RezGame
   * @param {string} source JSON format source archive
   * @description given a JSON source archive restore the game state to what was archived.
   */
  load(source) {
    const wrapper = JSON.parse(source);

    const archive_version = wrapper["rez_archive"];
    if (typeof archive_version == "undefined") {
      throw "JSON does not represent a Rez game archive!";
    } else if (archive_version != this.getAttribute("archive_format")) {
      throw (
        "JSON is v" +
        archive_version +
        " which is not supported (v" +
        this.getAttribute("archive_format") +
        ")!"
      );
    }

    const data = wrapper["data"];
    if (typeof data == "undefined") {
      throw "JSON does not contain data archive!";
    }

    // Load the game's attributes and properties
    this.loadData(data);

    const objs = data["objs"];
    if (typeof objs == "object") {
      for (const [id, obj_data] of Object.entries(objs)) {
        const obj = this.getGameObject(id);
        obj.loadData(obj_data);
      }
    }

    this.getAll().forEach((obj) => obj.runEvent("game_loaded"));
  },

  /**
   * @function getTaggedWith
   * @memberof RezGame
   * @param {string} tag
   * @returns {array} array of indexed game-objects that have the specified tag
   * @description returns all game-objects tagged with the specified tag
   */
  getTaggedWith(tag) {
    const objects = this.tag_index[tag];
    if (objects) {
      return Array.from(objects);
    } else {
      return [];
    }
  },

  /**
   * For each attribute defined on this game object, add it to the game-wide
   * index for that attribute.
   *
   * @param {basic_object} elem element whose attributes are to be indexed
   */
  addToAttrIndex(elem) {
    Object.entries(elem.attributes).forEach(([k, v]) => {
      this.indexAttribute(elem.id, k);
    });
  },

  /**
   * Adds the element to the per-attribute index.
   *
   * @param {string} elem_id id of element to add to the per-attr index
   * @param {string} attr_name
   */
  indexAttribute(elem_id, attr_name) {
    let index = this.attr_index[attr_name] ?? new Set();
    index.add(elem_id);
    this.attr_index[attr_name] = index;
  },

  /**
   * Return the ids of all game elements having the specified attribute.
   *
   * @param {string} attr_name
   * @returns {Array} matching element ids
   */
  getObjectsWith(attr_name) {
    const index = this.attr_index[attr_name] ?? new Set();
    return Array.from(index);
  },

  /**
   * @function indexObjectForTag
   * @memberof RezGame
   * @param {object} obj reference to a game-object
   * @param {string} tag
   * @description applies the specified tag to the spectified game-object
   */
  indexObjectForTag(obj, tag) {
    let objects = this.tag_index[tag];
    if (!objects) {
      objects = new Set([obj.id]);
      this.tag_index[tag] = objects;
    } else {
      objects.add(obj.id)
    }
  },

  /**
   * @function unindexObjectForTag
   * @memberof RezGame
   * @param {object} obj reference to a game-object
   * @param {string} tag a tag to remove
   * @description removes the specified tag from the specified game-object
   */
  unindexObjectForTag(obj, tag) {
    let objects = this.tag_index[tag];
    if (objects) {
      objects.delete(obj.id);
    }
  },

  /**
   * @function addToTagIndex
   * @memberof RezGame
   * @param {object} obj game-object
   * @description indexes the specified game-object for all tags in it's tags attribute
   */
  addToTagIndex(obj) {
    const tags = obj.getAttributeValue("tags", new Set());
    tags.forEach((tag) => this.indexObjectForTag(obj, tag));
  },

  /**
   * @function removeFromTagIndex
   * @memberof RezGame
   * @param {object} obj game-object
   * @description unindexes the specified object from all tags in its tags attribute
   */
  removeFromTagIndex(obj) {
    const tags = obj.getAttributeValue("tags", new Set());
    tags.forEach((tag) => this.unindexObjectForTag(obj, tag));
  },

  /**
   * @function addGameObject
   * @memberof RezGame
   * @param {object} obj game-object
   * @description adds an object representing a game element to the game world and automatically tagging it by its attributes
  */
  addGameObject(obj) {
    if (!isGameObject(obj)) {
      console.dir(obj);
      throw "Attempt to register non-game object!";
    }

    obj.game = this;
    this.game_objects.set(obj.id, obj);
    this.addToTagIndex(obj);
    this.addToAttrIndex(obj);
  },

  /**
   * @function getGameObject
   * @memberof RezGame
   * @param {string} id id of game-object
   * @param {boolean} should_throw (default: true)
   * @returns {basic_object|null} game-object or null
   * @description given an element id returns the appropriate game-object reference
   *
   * If should_throw is true an exception will be thrown if the element id
   * is not valid. Otherwise null is returned.
   */
  getGameObject(id, should_throw = true) {
    if (!this.game_objects.has(id)) {
      if (should_throw) {
        throw `No such ID |${id}| found!`;
      } else {
        return null;
      }
    } else {
      return this.game_objects.get(id);
    }
  },

  /**
   * @function getTypedGameObject
   * @memberof RezGame
   * @param {string} id id of game-object
   * @param {string} type game object type (e.g. 'actor' or 'item')
   * @param {boolean} should_throw (default: true)
   * @returns {basic_object|null} game-object or null
   */
  getTypedGameObject(id, type, should_throw = true) {
    const obj = this.getGameObject(id, type, should_throw);
    if(obj.game_object_type !== type) {
      if(should_throw) {
        throw `Game object |${id}| was expected to have type |${type}| but found |${obj.game_object_type}|!`
      } else {
        return null;
      }
    } else {
      return obj;
    }
  },

  /**
   * @function elementAttributeHasChanged
   * @memberof RezGame
   * @param {object} elem reference to game-object
   * @param {string} attr_name name of the attribute whose value has changed
   * @param {*} old_value value of the attribute before the change
   * @param {*} new_value value of the attribute after the change
   * @description should be called whenever an attribute value is changed
   *
   * Currently this function notifies the undo manager and the view
   */
  elementAttributeHasChanged(elem, attr_name, old_value, new_value) {
    if(this.undoManager) {
      this.undoManager.recordChange(elem.id, attr_name, old_value);
    }

    if(this.view) {
      this.view.updateBoundControls(elem.id, attr_name, new_value);
    }
  },

  /**
   * @function getRelationship
   * @memberof RezGame
   * @param {string} source_id id of game-object that holds the relationship
   * @param {string} target_id id of game-object to which the relationship refers
   * @returns {RezRelationship|null} the relationship object for this relationship
   * @description we can cheat looking up a relationship because we know how their IDs
   * are constructed.
   *
   * Note that in Rez relationships are unidirectional so that getRelationship("a", "b")
   * and getRelationship("b", "a") are different RezRelationship objects.
   */
  getRelationship(source_id, target_id) {
    const rel_id = "rel_" + source_id + "_" + target_id;
    return this.getGameObject(rel_id, false);
  },

  /**
   * @function filterObjects
   * @memberof RezGame
   * @param {function} pred predicate to filter with
   * @returns {array} game-objects passing the filter
   * @description filters all game-objects returning those for which the pred filter returns true
   */
  filterObjects(pred) {
    return Array.from(this.game_objects.values()).filter(pred);
  },

  /**
   * @function getAll
   * @memberof RezGame
   * @param {string} target_type (optional) a specific game object type (e.g. 'actor', 'item')
   * @returns {array} game-objects with the specified type
   * @description filters all game-objects returning those with the specified type
   */
  getAll(target_type) {
    if(target_type === undefined) {
      return Array.from(this.game_objects.values());
    } else {
      return this.filterObjects((obj) => obj.game_object_type == target_type);
    }
  },

  /**
   * @function startSceneWithId
   * @memberof RezGame
   * @param {string} scene_id id of scene game-object
   * @param {object} params data to pass to the new scene
   * @description finish the current scene and start the new scene with the given id
   */
  startSceneWithId(scene_id, params = {}) {
    if (scene_id == null) {
      throw "new_scene_id cannot be null!";
    }

    if (this.current_scene) {
      this.current_scene.finish();
    }

    const scene = $(scene_id);
    if(scene.game_object_type !== "scene") {
      throw `Attempt to switch scene to game object |${scene_id}| which is a |${scene.game_object_type}|!`;
    }

    this.current_scene = scene;

    const layout = scene.getViewLayout();
    layout.params = params;

    this.setViewContent(layout);
    this.clearFlashMessages();
    scene.start();
    scene.ready();
  },

  /**
   * @function interludeSceneWithId
   * @memberof RezGame
   * @param {string} scene_id
   * @param {object} params data to pass to the new scene
   * @description interrupts the current scene, pushing it to the scene stack, and then starts the new scene with the given id
   */
  interludeSceneWithId(scene_id, params = {}) {
    console.log(`Interlude from |${this.current_scene_id}| to |${scene_id}|`);

    // Save the state of the current scene
    this.pushScene();

    const scene = $(scene_id);
    if(scene.game_object_type !== "scene") {
      throw `Attempt to interlude to game object |${new_scene_id}| which is a |${scene.game_object_type}|!`;
    }

    this.current_scene = scene;

    const layout = scene.getViewLayout();
    layout.params = params;

    this.setViewContent(scene.getViewLayout());
    this.clearFlashMessages();

    scene.start();
    scene.ready();
  },

  /**
   * @function resumePrevScene
   * @memberof RezGame
   * @param {object} params data to pass back to the previous scene
   * @description finishes the current scene, then pops the previous scene from the scene stack and resumes it
   */
  resumePrevScene(params = {}) {
    console.log(`Resume from |${this.current_scene_id}|`);
    if (!this.canResume()) {
      throw "Cannot resume without a scene on the stack!";
    } else {
      // Let the interlude know we're done
      this.current_scene.finish();
      this.popScene(params);

      const layout = this.current_scene.getViewLayout();
      // Merge any new params into the existing params
      layout.params = {...layout.params, ...params};
      this.updateView();
    }
  },

  /**
   * Informs the view of new content to be rendered. It is left up to the view
   * & its layout to determine how this affects any existing content of the view.
   *
   * @memberof RezGame
   * @param {Object} content block to be added to the view
   */
  setViewContent(content) {
    this.view.getLayout().addContent(content);
  },

  /**
   * @function updateView
   * @memberof RezGame
   * @description re-renders the view calling the 'before_render' and 'after_render'
   * game event handlers
   */
  updateView() {
    console.log("Updating the view");
    this.runEvent("before_render", {});
    this.view.update();
    this.runEvent("after_render", {});
    this.clearFlashMessages();
  },

  /**
   * @function canResume
   * @memberof RezGame
   * @returns {boolean}
   * @description returns true if there is at least one scene in the scene stack
   */
  canResume() {
    return this.$scene_stack.length > 0;
  },

  /**
   * @function pushScene
   * @memberof RezGame
   * @description interrupts the current scene and puts it on the scene stack
   */
  pushScene() {
    this.current_scene.interrupt();
    this.$scene_stack.push(this.current_scene_id);
    this.view.pushLayout(new RezSingleLayout("scene", this));
  },

  /**
   * @function popScene
   * @memberof RezGame
   * @param {object} params data to be passed to the scene being resumed
   * @description removes the top object of the scene stack and makes it the current scene
   */
  popScene(params = {}) {
    this.view.popLayout();
    this.current_scene_id = this.$scene_stack.pop();
    this.current_scene.resume(params);
  },

  /**
   * @function setViewLayout
   * @memberof RezGame
   * @param {*} layout ???
   * @description ???
   */
  setViewLayout(layout) {
    this.view.setLayout(layout);
  },

  /**
   * @function start
   * @memberof RezGame
   * @param {string} container_id id of the HTML element into which game content is rendered
   * @description called automatically from the index.html this runs init on the registered game
   * objects then starts the view and starts the initial scene
   */
  start(container_id) {
    console.log("> Game.start");

    // Init every object, will also trigger on_init for any object that defines it
    for (let init_level of this.initLevels()) {
      console.log("init/" + init_level);

      this.init(init_level);

      const game_objects = this.getAttribute("$init_order");

      this.$init_order.forEach(function (obj_id) {
        const obj = this.getGameObject(obj_id);
        obj.init(init_level);
      }, this);
    }

    this.getAll().forEach((obj) => {
      obj.runEvent("game_started", {})
    });

    this.view = new RezView(
      container_id,
      this.event_processor,
      new RezSingleLayout("game", this)
    );

    this.startSceneWithId(this.initial_scene_id);
  },

  /**
   * @function getEnabledSystems
   * @memberof RezGame
   * @returns {array} all 'system' game-objects with attribute enabled=true
   */
  getEnabledSystems() {
    const filter = (o) => o.game_object_type === "system" && o.getAttributeValue("enabled");
    const order = (sys_a, sys_b) => sys_b.getAttributeValue("priority") - sys_a.getAttributeValue("priority");
    return this.filterObjects(filter).sort(order);
  },

  /**
   * @function addFlashMessage
   * @memberof RezGame
   * @param {string} message
   * @description adds the given message to the flash to be displayed on the next render
   */
  addFlashMessage(message) {
    this.$flash_messages.push(message);
  },

  /**
   * @function clearFlashMessages
   * @memberof RezGame
   * @description empties the flash messages
   */
  clearFlashMessages() {
    this.$flash_messages = [];
  },
};

window.Rez.RezGame = RezGame;
