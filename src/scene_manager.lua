local SceneManager = {
    scenes = {},
    current = nil
}

function SceneManager.register(name, scene)
    SceneManager.scenes[name] = scene
end

function SceneManager.switch(name)
    if SceneManager.current and SceneManager.current.leave then
        SceneManager.current.leave()
    end
    SceneManager.current = SceneManager.scenes[name]
    if SceneManager.current and SceneManager.current.enter then
        SceneManager.current.enter()
    end
end

function SceneManager.update(dt)
    if SceneManager.current and SceneManager.current.update then
        SceneManager.current.update(dt)
    end
end

function SceneManager.keypressed(key)
    if SceneManager.current and SceneManager.current.keypressed then
        SceneManager.current.keypressed(key)
    end
end

function SceneManager.draw()
    if SceneManager.current and SceneManager.current.draw then
        SceneManager.current.draw()
    end
end

return SceneManager