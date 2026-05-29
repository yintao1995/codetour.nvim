local state = require("codetour.state")

describe("codetour.state", function()
  before_each(function()
    state.reset()
  end)

  it("starts with no active tour", function()
    assert.is_nil(state.active_tour())
    assert.is_nil(state.active_step())
  end)

  it("set_active_tour stores tour and resets step to 1", function()
    local tour = { title = "T", steps = { { line = 1 }, { line = 2 } } }
    state.set_active_tour(tour)
    assert.equals(tour, state.active_tour())
    assert.equals(1, state.active_step_index())
    assert.equals(tour.steps[1], state.active_step())
  end)

  it("set_step_index clamps and emits :step_changed", function()
    local tour = { title = "T", steps = { { line = 1 }, { line = 2 } } }
    state.set_active_tour(tour)
    local seen = {}
    state.on("step_changed", function(idx)
      table.insert(seen, idx)
    end)
    state.set_step_index(2)
    state.set_step_index(99)
    state.set_step_index(0)
    assert.same({ 2, 2, 1 }, seen)
  end)

  it("end_tour clears state and emits :tour_ended", function()
    local tour = { title = "T", steps = { { line = 1 } } }
    state.set_active_tour(tour)
    local ended = false
    state.on("tour_ended", function()
      ended = true
    end)
    state.end_tour()
    assert.is_nil(state.active_tour())
    assert.is_true(ended)
  end)
end)
