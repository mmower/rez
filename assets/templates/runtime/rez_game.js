//-----------------------------------------------------------------------------
// Game
//-----------------------------------------------------------------------------

let game_proto = {
  __proto__: basic_object,
  targetType: "game",

  get template() {
    return this.getAttribute("layout_template");
  },

  $(id) {
    return this.getGameObject(id);
  },

  initLevels() {
    return [0, 1, 2, 3];
  },

  saveFileName(prefix) {
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

  toJSON() {
    let data = this.archiveDataContainer();
    data = this.dataWithArchivedAttributes(data);
    data = this.dataWithArchivedProperties(data);
    data = this.dataWithArchivedObjects(data);

    return {
      rez_archive: this.getAttribute("archive_format"),
      data: data,
    };
  },

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

  save() {
    this.runEvent("save", {});

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

  load(json) {
    const wrapper = JSON.parse(json);

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

    this.runEvent("load", {});
  },

  indexObjectForTag(obj, tag) {
    let objects = this.tag_index[tag];
    if (!objects) {
      objects = new Set([obj.id]);
      this.tag_index[tag] = objects;
    } else {
      objects.add(obj.id);
    }
  },

  unindexObjectForTag(obj, tag) {
    let objects = this.tag_index[tag];
    if (objects) {
      objects.delete(obj.id);
    }
  },

  addToTagIndex(obj) {
    const tags = obj.getAttributeValue("tags", new Set());
    tags.forEach((tag) => this.indexObjectForTag(obj, tag));
  },

  removeFromTagIndex(obj) {
    const tags = obj.getAttributeValue("tags", new Set());
    tags.forEach((tag) => this.unindexObjectForTag(obj, tag));
  },

  /*
  Adds an object representing a game element to the game data.

  The static objects defined in the game files will appear in the games
  init_order property. Dynamically generated objects should be init'd
  separately.
  */
  addGameObject(obj) {
    if (!isGameObject(obj)) {
      console.dir(obj);
      throw "Attempt to register non-game object!";
    }

    obj.game = this;
    this.game_objects.set(obj.id, obj);
    this.addToTagIndex(obj);
  },

  getGameObject(id, should_throw = true) {
    if (!this.game_objects.has(id)) {
      if (should_throw) {
        throw "No such ID |" + id + "| found!";
      } else {
        return null;
      }
    }
    return this.game_objects.get(id);
  },

  /*
   * We can cheat looking up a relationship because we know how their IDs
   * are constructed.
   */
  getRelationship(source_id, target_id) {
    const rel_id = "rel_" + source_id + "_" + target_id;
    return this.getGameObject(rel_id, false);
  },

  getTaggedWith(tag) {
    const objects = this.tag_index[tag];
    if (objects) {
      return Array.from(objects);
    } else {
      return [];
    }
  },

  filterObjects(pred) {
    return Array.from(this.game_objects.values()).filter(pred);
  },

  getAll(target_type) {
    return Array.from(this.game_objects.values()).filter(
      (obj) => obj.game_object_type == target_type
    );
  },

  getCurrentScene() {
    return this.getGameObject(this.current_scene_id);
  },

  setCurrentScene(new_scene_id) {
    if (new_scene_id == null) {
      throw "new_scene_id cannot be null!";
    }

    this.current_scene_id = new_scene_id;
    const scene = this.getCurrentScene();
    this.setViewContent(scene.getLayout());
    this.clearFlashMessages();
    this.getCurrentScene().start();
  },

  setViewContent(content) {
    this.view.getLayout().addContent(content);
  },

  getTarget(target_id) {
    if (target_id == this.id) {
      return this;
    } else {
      return this.getGameObject(target_id);
    }
  },

  updateView() {
    console.log("Updating the view");
    this.view.update();
  },

  interludeWithScene(interlude_scene_id) {
    if (interlude_scene_id == null) {
      throw "interlude_scene_id cannot be null!";
    } else if (this.getCurrentScene() == null) {
      throw "cannot interlude without a current scene!";
    }

    console.log(
      "Interlude from " + this.current_scene_id + " to " + interlude_scene_id
    );

    // Save the state of the current scene
    this.pushScene();

    this.setCurrentScene(interlude_scene_id);
    this.updateView();
  },

  resumePrevScene() {
    console.log("Resume from " + this.current_scene_id);
    if (this.scene_stack.length < 1) {
      throw "Cannot resume without a scene on the stack!";
    } else {
      // Let the interlude know we're done
      this.getCurrentScene().finish();

      this.popScene();
      this.updateView();
    }
  },

  pushScene() {
    this.getCurrentScene().interrupt();
    this.scene_stack.push(this.current_scene_id);
    this.view.pushLayout(new RezSingleLayout(this));
  },

  popScene() {
    this.view.popLayout();
    this.current_scene_id = this.scene_stack.pop();
    this.getCurrentScene().resume();
  },

  setViewLayout(layout) {
    this.view.setLayout(layout);
  },

  start(container_id) {
    console.log("> Game.start");
    this.view = new RezView(container_id, this, new RezSingleLayout(this));

    // Init every object, will also trigger on_init for any object that defines it
    for (let init_level of this.initLevels()) {
      this.init_order.forEach(function (obj_id) {
        const obj = this.getGameObject(obj_id);
        obj.init(init_level);
      }, this);
    }

    // this.container_id = container_id;
    this.runEvent("start", {});

    const initial_scene_id = this.getAttributeValue("initial_scene");
    this.setCurrentScene(initial_scene_id);
  },

  getEnabledSystems() {
    return this.getAll("system")
      .filter((system) => system.getAttribute("enabled") == true)
      .sort(
        (sys1, sys2) =>
          sys1.getAttributeValue("priority") >
          sys2.getAttributeValue("priority")
      );
  },

  // Handle events coming from the browser

  handleBrowserEvent(evt) {
    if (evt.type == "click") {
      return this.handleBrowserClickEvent(evt);
    } else if (evt.type == "input") {
      return this.handleBrowserInputEvent(evt);
    } else if (evt.type == "submit") {
      return this.handleBrowserSubmitEvent(evt);
    } else {
      return false;
    }
  },

  handleBrowserClickEvent(evt) {
    if (!evt.target.dataset.event) {
      return false;
    }

    const event_name = evt.target.dataset.event;
    if (event_name == "card") {
      return this.handleCardEvent(evt);
    } else if (event_name == "shift") {
      return this.handleShiftEvent(evt);
    } else if (event_name == "interlude") {
      return this.handleInterludeEvent(evt);
    } else if (event_name == "resume") {
      return this.handleResumeEvent(evt);
    } else {
      return this.handleCustomEvent(event_name, evt);
    }
  },

  handleCustomEvent(event_name, evt) {
    const handler = this.eventHandler(event_name);
    if (handler && typeof handler == "function") {
      return handler(this, evt);
    } else {
      return this.getCurrentScene().handleCustomEvent(event_name, evt);
    }
  },

  handleCardEvent(evt) {
    console.log("Handle card event");
    const card_id = evt.target.dataset.target;
    this.getCurrentScene().playCardWithId(card_id);
    return true;
  },

  handleShiftEvent(evt) {
    console.log("Handle shift event");
    const scene_id = evt.target.dataset.target;
    this.setCurrentScene(scene_id);
    return true;
  },

  handleInterludeEvent(evt) {
    console.log("Handle interlude event");
    const scene_id = evt.target.dataset.target;
    this.interludeWithScene(scene_id);
    return true;
  },

  handleResumeEvent(evt) {
    console.log("Handle resume event");
    this.resumePrevScene();
    return true;
  },

  handleBrowserInputEvent(evt) {
    console.log("Handle input event");
    const card_div = evt.target.closest(
      ".active_card > div.card, .active_block > div.card"
    );
    if (!card_div) {
      throw "Cannot find div for input " + evt.target.id + "!";
    }

    const card_id = card_div.dataset.card;
    if (!card_id) {
      throw "Cannot get card id for input" + evt.target.id + "!";
    }

    const card = $(card_id);
    return card.runEvent("input", { evt: evt });
  },

  handleBrowserSubmitEvent(evt) {
    console.log("Handle submit event");

    const form_name = evt.target.getAttribute("name");
    if (!form_name) {
      throw "Cannot get form name!";
    }

    const card_div = evt.target.closest(
      ".active_card > div.card, .active_block > div.card"
    );
    if (!card_div) {
      throw "Cannot find div for form: " + form_name + "!";
    }

    const card_id = card_div.dataset.card;
    const card = $(card_id);

    return card.runEvent(form_name, { form: evt.target });
  },

  runTick() {
    this.getEnabledSystems().forEach(function (system) {
      system.runEvent("tick", this.wmem);
    });
  },

  addFlashMessage(message) {
    this.flash.push(message);
  },

  clearFlashMessages() {
    this.flash = [];
  },
};

function RezGame(init_order, attributes) {
  this.id = "game";
  this.game_object_type = "game";
  this.init_order = init_order;
  this.attributes = attributes;
  this.tag_index = {};
  this.scene_stack = [];
  this.current_scene_id = null;
  this.flash = [];
  this.wmem = { game: this };
  this.game_objects = new Map();
  this.properties_to_archive = [
    "scene_stack",
    "current_scene_id",
    "wmem",
    "tag_index",
    "renderer",
  ];
  this.changed_attributes = [];
  this.$ = this.getGameObject;
}

RezGame.prototype = game_proto;
RezGame.prototype.constructor = RezGame;
window.Rez.Game = RezGame;
