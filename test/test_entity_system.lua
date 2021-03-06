local lu = require('test.luaunit')
local entitas = require("entitas")
local Entity =entitas.Entity
local Context = entitas.Context
local Matcher = entitas.Matcher
local Collector = entitas.Collector
local MakeComponent = entitas.MakeComponent
local GroupEvent = entitas.GroupEvent
local EntityIndex = entitas.EntityIndex
local PrimaryEntityIndex = entitas.PrimaryEntityIndex
local Systems = entitas.Systems
local ReactiveSystem = entitas.ReactiveSystem

local Position = MakeComponent("Position", "x", "y", "z")
local Movable = MakeComponent("Movable", "speed")
local Person = MakeComponent("Person", "name", "age")
local Counter = MakeComponent("Counter", "num")
local PlayerData = MakeComponent("PlayerData", "name")

local GLOBAL = _G

GLOBAL.test_collector = function()
    local context = Context.new()
    local group = context:get_group(Matcher({Position}))
    local pair = {}
    pair[group] = GroupEvent.ADDED|GroupEvent.REMOVED
    local collector = Collector.new(pair)
    local _entity = context:create_entity()
    _entity:add(Position,1,2,3)
    lu.assertEquals(collector.entities:size(),1)
    context:destroy_entity(_entity)
    lu.assertEquals(collector.entities:size(),0)
    collector:clear_entities()
    collector:deactivate()
end

GLOBAL.test_context = function()
    local _context = Context.new()
    local _entity = _context:create_entity()

    assert(Context.create_entity)
    assert(Context.has_entity)
    assert(Context.destroy_entity)
    assert(Context.get_group)
    assert(Context.set_unique_component)
    assert(Context.get_unique_component)

    assert(_context:has_entity(_entity))
    lu.assertEquals(_context:entity_size(), 1)
    _context:destroy_entity(_entity)
    assert(not _context:has_entity(_entity))
    -- reuse
    local _e2 = _context:create_entity()
    assert(_context:has_entity(_entity))
    lu.assertEquals(_context:entity_size(), 1)

    _context:set_unique_component(Counter, 101)
    local cmp = _context:get_unique_component(Counter)
    assert(cmp.num == 101)
end

GLOBAL.test_index = function()
    local context = Context.new()
    local group = context:get_group(Matcher({Person}))
    local index = EntityIndex.new(Person, group, 'age')
    context:add_entity_index(index)
    local adam = context:create_entity()
    adam:add(Person, "Adam", 42)
    local eve = context:create_entity()
    eve:add(Person, "Eve", 42)

    local idx = context:get_entity_index(Person)
    local entities = idx:get_entities(42)

    assert(entities:has(adam))
    assert(entities:has(eve))
end

GLOBAL.test_primary_index =  function()
    local context = Context.new()
    local group = context:get_group(Matcher({Person}))
    local primary_index = PrimaryEntityIndex.new(Person, group, 'name')
    context:add_entity_index(primary_index)

    local adam = context:create_entity()
    adam:add(Person, "Adam", 42)

    local eve = context:create_entity()
    eve:add(Person, "Eve", 42)

    local idx = context:get_entity_index(Person)
    local ety = idx:get_entity("Eve")
    assert(primary_index == idx)
    assert(ety == eve)
end

GLOBAL.test_entity = function()
    local entity = Entity.new()

    entity:activate(0)
    entity:add(Position, 1, 4, 5)
    assert(entity:has(Position))
    assert(entity:has_any({Position}))

    local pos = entity:get(Position)
    assert(pos.x == 1)
    assert(pos.y == 4)
    assert(pos.z == 5)

    entity:replace(Position, 5, 6)

    entity:replace(Person, "wang")

    assert(entity:get(Position).x == 5)
    assert(entity:get(Position).y == 6)

    entity:remove(Position)
    assert(not entity:has(Position))

    entity:add(Position, 1, 4, 5)
    entity:add(Movable, 0.56)
    assert(entity:has_all({Position, Movable}))
    entity:destroy()
    assert(not entity:has_all({Position, Movable}))
end

GLOBAL.test_group = function()
    local _context = Context.new()
    local _entity = _context:create_entity()

    _entity:add(Movable, 1)

    local _group = _context:get_group(Matcher({Movable}))
    local _group2 = _context:get_group(Matcher({Movable}))
    assert(_group==_group2)

    assert(_group.entities:size() == 1)
    assert(_group:single_entity():has(Movable))

    assert(_group:single_entity() == _entity)
    _entity:replace(Movable, 2)
    assert(_group:single_entity() == _entity)
    _entity:remove(Movable)
    assert(not _group:single_entity())

    _entity:add(Movable, 3)

    local _entity2 = _context:create_entity()
    _entity2:add(Movable, 10)
    lu.assertEquals(_group.entities:size(), 2)
    local entities = _group.entities

    assert(entities:has(_entity))
    assert(entities:has(_entity2))
end

GLOBAL.test_matches = function()
    local CompA = MakeComponent("CompA", "")
    local CompB = MakeComponent("CompB", "")
    local CompC = MakeComponent("CompC", "")
    local CompD = MakeComponent("CompD", "")
    local CompE = MakeComponent("CompE", "")
    local CompF = MakeComponent("CompF", "")

    local ea = Entity.new()
    local eb = Entity.new()
    local ec = Entity.new()
    ea:activate(0)
    eb:activate(1)
    ec:activate(2)
    ea:add(CompA)
    ea:add(CompB)
    ea:add(CompC)
    ea:add(CompE)
    eb:add(CompA)
    eb:add(CompB)
    eb:add(CompC)
    eb:add(CompE)
    eb:add(CompF)
    ec:add(CompB)
    ec:add(CompC)
    ec:add(CompD)

    local matcher = Matcher(
        {CompA, CompB, CompC},
        {CompD, CompE},
        {CompF}
    )
    assert(matcher:match_entity(ea))
    assert(not matcher:match_entity(eb))
    assert(not matcher:match_entity(ec))
end

GLOBAL.test_10000_entities = function()
    local _context = Context.new()

    for i = 1, 10000 do
        local _entity = _context:create_entity()
        _entity:add(Movable, i)
        _entity:add(PlayerData, i)
    end

    local _group = _context:get_group(Matcher({Movable}))

    assert(_group.entities:size() == 10000)

    local index = EntityIndex.new(PlayerData, _group, "name")
    _context:add_entity_index(index)

    local idx = _context:get_entity_index(PlayerData)
    local entities = idx:get_entities(100)
    assert(entities:size() == 1)
end


GLOBAL.test_system = function()

    -------------------------------------------
    local StartGame = class("StartGame")
    function StartGame:ctor(context)
        self.context = context
    end

    function StartGame:initialize()
        print("StartGame initialize")
        local entity = self.context:create_entity()
        entity:add(Movable,123)
    end

    -------------------------------------------
    local EndSystem = class("EndSystem")
    function EndSystem:ctor(context)
        self.context = context
    end

    function EndSystem:tear_down()
        print("EndSystem tear_down")
    end

    -------------------------------------------
    local MoveSystem = class("MoveSystem", ReactiveSystem)

    function MoveSystem:ctor(context)
        MoveSystem.super.ctor(self, context)
    end

    local trigger = {
        {
            Matcher({Movable}),
            GroupEvent.ADDED | GroupEvent.UPDATE
        }
    }

    function MoveSystem:get_trigger()
        return trigger
    end

    function MoveSystem:filter(entity)
        return entity:has(Movable)
    end

    function MoveSystem:execute(es)
        es:foreach(function( e  )
            print("ReactiveSystem: add entity with component Movable.",e)
        end)
    end

    local _context = Context.new()
    local systems = Systems.new()
    systems:add(StartGame.new(_context))
    systems:add(MoveSystem.new(_context))
    systems:add(EndSystem.new(_context))

    systems:initialize()

    systems:execute()

    systems:tear_down()
end

local runner = lu.LuaUnit.new()
runner:setOutputType("tap")
local ret = runner:runSuite()
if 0 == ret then
    print("test_entity_system success with result "..ret)
else
    print("test_entity_system failed with result "..ret)
end

