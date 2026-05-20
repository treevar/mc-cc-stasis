GitHubLoader = {user = nil, repo = nil, branch = nil}

function GitHubLoader:new(user, repo, branch)
    local o = {}
    setmetatable(o, self)
    o.user = user
    o.repo = repo
    o.branch = branch or "main"
    self.__index = self
    return o
end

function GitHubLoader:checkUrl(url)
    local bad = {
        "..", --Path traversal
        "%2E%2E",
        "%2e%2e"
    }
    if(type(url) ~= "string") then
        return false
    end
    for _, seq in ipairs(bad) do
        if(string.find(url, seq, 1, true)) then
            return false
        end
    end

    return true
end

function GitHubLoader:get(urlPath, filePath)
    if(not filePath) then
        filePath = urlPath
    end
    --Build URL
    local url = "https://raw.githubusercontent.com/" .. self.user .. "/" .. self.repo .. "/refs/heads/" ..self.branch .. "/" .. urlPath
    if(not http.checkURL(url) or not self:checkUrl(url)) then
        return false
    end
    --Req
    local res = http.get(url)
    if(res == nil or res.getResponseCode() ~= 200) then
        return false
    end
    --Create Dir
    local dir = fs.getDir(filePath) or "/"
    if(not fs.exists(dir)) then
        fs.makeDir(dir)
    end
    --Write File
    local file = fs.open(filePath, "w")
    file.write(res.readAll())
    file.close()
    res.close()
    return true
end

return GitHubLoader