-- ========================================================
-- @File    : ResourceAmend.lua
-- @Brief   : 资源修正
-- ========================================================

---@class ResourceAmend 资源修正
ResourceAmend = ResourceAmend or { tbAmend2D = {}, tbAmendSpine = {}, tbAmendSequence = {}, tbAmend3D = {}, tbAmendAudio = {}, tbCGSpine = {}}

ResourceAmend.GID = 117
ResourceAmend.SID_BLACK = 17

local sProjectDir = UE4.UBlueprintPathsLibrary.ProjectDir()

if IsMobile() then
    sProjectDir = IsAndroid() and (UE4.UBlueprintPathsLibrary.ProjectPersistentDownloadDir() .. '/') or UE4.UBlueprintPathsLibrary.ProjectDir()
else
    sProjectDir = UE4.UBlueprintPathsLibrary.GetPath(UE4.UBlueprintPathsLibrary.GetPath(UE4.UBlueprintPathsLibrary.RootDir())) .. '/'
end

---方便测试
if WithEditor then
    sProjectDir = UE4.UBlueprintPathsLibrary.ProjectDir()
end

ResourceAmend.bNegated = false
ResourceAmend.bOpenAmend = false
ResourceAmend.bServerShield = false

---读取文件
---@param sFilePath string 文件路径
function ResourceAmend.ReadTxt(sFilePath)
    function splitFun(str,reps)
        local resultStrList = {}
        string.gsub(str,'[^'..reps..']+',function (w)
            table.insert(resultStrList,w)
        end)
        return resultStrList
    end
    local tbData = {}
    if UE4.UBlueprintPathsLibrary.FileExists(sFilePath) then
        local pFile = UE4.File()
        local bSuc = pFile:Open(sFilePath, 'r')
        if bSuc then
            local sRead = UE4.File.Read(pFile, 'a')
            print('ResourceAmend.ReadTxt :', sRead)
            if sRead and #sRead > 0 then
                local tbLine = splitFun(sRead, '\n') or {}
                for _, line in ipairs(tbLine or {}) do
                    local tb = splitFun(line, '=')
                    local sKeyName = tb[1] or ''
                    sKeyName = string.gsub(sKeyName, '%s+', '')
                    local sValue = tb[2] or ''
                    tbData[sKeyName] = string.gsub(sValue, '%s+', '') 
                end
            end
        else
            print('ResourceAmend.ReadTxt : open fail', sFilePath)
        end
        pFile:Close()
    else
        print('ResourceAmend.ReadTxt : file not exists', sFilePath)
    end
    return tbData
end

---读取本地设置
function ResourceAmend.ReadLocalFlag()
    local sFilePath = sProjectDir .. 'localization.txt'
    local pFile = UE4.File()

    ---不存在文件，需要创建文件
    if UE4.UBlueprintPathsLibrary.FileExists(sFilePath) then
        --local tbData = ResourceAmend.ReadTxt(sFilePath) or {}
        local nFlag = UE4.UUMGLibrary.GetLocalizationFlag()
        ResourceAmend.bNegated = (nFlag == 1)
        print('ResourceAmend.ReadLocalFlag :', nFlag)
    else
        local bSuc = pFile:Open(sFilePath, 'a+')
        if bSuc then
            local nDefaultFlag = UE4.UGameLibrary.GetGameIni_Int('Distribution', 'DefaultLocalization', 0)
            pFile:Write(string.format('localization = %d', nDefaultFlag))
            ResourceAmend.bNegated = nDefaultFlag == 1
        else
            ResourceAmend.bNegated = false
        end
        pFile:Flush()
        print('ResourceAmend.ReadLocalFlag Creat------------->', ResourceAmend.bNegated)
    end
    pFile:Close()
end

---检查道具获取时间是否在和谐时间内
function ResourceAmend.CheckTime(tbGDPL)
    if ResourceAmend.bServerShield then return true end
    ResourceAmend.tbCacheTime = ResourceAmend.tbCacheTime or {}
    if not tbGDPL then return true end
    local g, d, p, l = table.unpack(tbGDPL)
    local pTemplate = UE4.UItem.FindTemplate(g, d, p, l)
    if not pTemplate then return true end
    local sTime = pTemplate.ATime
    if not sTime or sTime == '' then return true end
    local nATime = ParseTime(string.sub(sTime, 2, -2))
    if nATime <= 0 then return true end

    local sGDPL = string.format('%s-%s-%s-%s', g, d, p, l)
    local nGetTime = -1
    if ResourceAmend.tbCacheTime[sGDPL] then
        nGetTime = ResourceAmend.tbCacheTime[sGDPL]
    else
        local tbItem = me:GetItemsByGDPL(g, d, p, l)
        if tbItem:Length() > 0 then
            local pItem = tbItem:Get(1)
            nGetTime = pItem:UserData()
            ResourceAmend.tbCacheTime[sGDPL] = nGetTime
        else
            return true
        end
    end

    if nGetTime <= 0 then return false end
    return nGetTime > nATime
end


function ResourceAmend.IsNegated()
    return ResourceAmend.bNegated
end

---是否资源修正
function ResourceAmend.IsFix()
    if ResourceAmend.bNegated then
        return false
    end
    return ResourceAmend.bOpenAmend
end

---是否修正3D资源路径（模型、材质）
---@param sPath string 资源路径
function ResourceAmend.IsFix3DPath(sPath)
    if not sPath then return false end
    if not ResourceAmend.IsFix() then return false end
    local tbCfg = ResourceAmend.tbAmend3D[sPath]
    if not tbCfg then return true end
    return ResourceAmend.CheckTime(tbCfg.tbGDPL)
end

---是否修正GDPL对应的功能
function ResourceAmend.IsFixGDPL(g, d, p, l)
    if g and d and p and l and tonumber(g) > 0 then 
		return ResourceAmend.IsFix() and ResourceAmend.CheckTime({g, d, p, l})
	else 
		return ResourceAmend.IsFix() and true or false
	end
end

---修正图片id
function ResourceAmend.AmendImageId(nId)
    if not nId then return end
    if not ResourceAmend.IsFix() then return nId end
    local tbCfg = ResourceAmend.tbAmend2D[nId]
    if tbCfg and ResourceAmend.CheckTime(tbCfg.tbGDPL) then
        return tbCfg.n18ban_path
    end
    return nId
end

---修正Spine资源
function ResourceAmend.AmendSpinePath(sPath)
    if not sPath then return end
    if not ResourceAmend.IsFix() then return sPath end
    local tbCfg = ResourceAmend.tbAmendSpine[sPath]
    if tbCfg and ResourceAmend.CheckTime(tbCfg.tbGDPL) then
        return tbCfg.s18ban_path
    end
    return sPath
end

---修正CGSpine资源
function ResourceAmend.AmendCGSpinePath(sPath)
    if not sPath then return end
    if not ResourceAmend.IsFix() then return sPath end
    local tbCfg = ResourceAmend.tbCGSpine[sPath]
    if tbCfg then
        return tbCfg.s18ban_path
    end
    return sPath
end

---修正Sequence资源
function ResourceAmend.AmendSequencePath(sPath)
    if not sPath then return end
    if not ResourceAmend.IsFix() then return sPath end
    local tbCfg = ResourceAmend.tbAmendSequence[sPath]
    if tbCfg and ResourceAmend.CheckTime(tbCfg.tbGDPL) then
        return tbCfg.s18ban_path
    end
    return sPath
end

---修正视频资源
function ResourceAmend.AmendMoviePath(sPath)
    if not sPath then return end
    if not ResourceAmend.IsFix() then return sPath end
    local tbCfg = ResourceAmend.tbAmendSpine[sPath]
    if tbCfg and ResourceAmend.CheckTime(tbCfg.tbGDPL) then
        return tbCfg.s18ban_path
    end
    return sPath
end

---修正音效
function ResourceAmend.AmendAudioId(nId)
    if not nId then return end
    if not ResourceAmend.IsFix() then return nId end
    local tbCfg = ResourceAmend.tbAmendAudio[nId]
    if tbCfg and ResourceAmend.CheckTime(tbCfg.tbGDPL) then
        return tbCfg.n18ban_path or nId
    end
    return nId
end

function ResourceAmend.FixSpineWidget(pWidget)
    if not pWidget then return end
    if not pWidget.Atlas or not pWidget.SkeletonData then return end

    local sOldAtlasPathName = UE4.UKismetSystemLibrary.GetPathName(pWidget.Atlas)
    local sFixAtlasPathName = ResourceAmend.AmendSpinePath(sOldAtlasPathName)
    if sOldAtlasPathName == sFixAtlasPathName then return end

    local pFixAtlas = UE4.UGameAssetManager.GameLoadAssetFormPath(sFixAtlasPathName)
    if not pFixAtlas then
        print('ResourceAmend.FixSpineWidget Atlas Error', sFixAtlasPathName) 
        return 
    end
    pWidget.Atlas = pFixAtlas

    local sOldSkeletonDataPathName = UE4.UKismetSystemLibrary.GetPathName(pWidget.SkeletonData)
    local sFixSkeletonDataPathName = ResourceAmend.AmendSpinePath(sOldSkeletonDataPathName)
    if sOldSkeletonDataPathName == sFixSkeletonDataPathName then return end

    local pFixSkeletonData = UE4.UGameAssetManager.GameLoadAssetFormPath(sFixSkeletonDataPathName)
    if not pFixSkeletonData then
        print('ResourceAmend.FixSpineWidget SkeletonData Error', sFixSkeletonDataPathName)  
        return 
    end
    pWidget.SkeletonData = pFixSkeletonData
end


---加载修正信息
function ResourceAmend.LoadAmend2DCfg()
    local tbFile = LoadCsv("resource/resource_amend/amend_2D.txt", 1)
    for _, tbLine in pairs(tbFile) do
        local nOriginal_Path = tonumber(tbLine.Original_Path)
        local n18ban_path = tonumber(tbLine['18ban_path'])
        local tbGDPL = Eval(tbLine.GDPL)

        if nOriginal_Path then
            ResourceAmend.tbAmend2D[nOriginal_Path] = {n18ban_path = n18ban_path, tbGDPL = tbGDPL}
        end
    end
    print('Load ../resource/resource_amend/amend_2D.txt')
end

---加载修正信息
function ResourceAmend.LoadAmendSpineCfg()
    local tbFile = LoadCsv("resource/resource_amend/amend_Spine.txt", 1)
    for _, tbLine in pairs(tbFile) do
        local sOriginal_Path = tbLine.Original_Path
        local s18ban_path = tbLine['18ban_path']
        local tbGDPL = Eval(tbLine.GDPL)

        if sOriginal_Path then
            ResourceAmend.tbAmendSpine[sOriginal_Path] = {s18ban_path = s18ban_path, tbGDPL = tbGDPL}
        end
    end
    print('Load ../resource/resource_amend/amend_Spine.txt')
end

-- 
function ResourceAmend.LoadAmendCGSpine()
    local tbFile = LoadCsv("resource/resource_amend/amend_CGSpine.txt", 1)
    for _, tbLine in pairs(tbFile) do
        local sOriginal_Path = tbLine.Original_Path
        local s18ban_path = tbLine['18ban_path']
        if sOriginal_Path then
            ResourceAmend.tbCGSpine[sOriginal_Path] = {s18ban_path = s18ban_path}
        end
    end
    print('Load ../resource/resource_amend/amend_CGSpine.txt')
end

---加载修正sequence信息
function ResourceAmend.LoadAmendSequenceCfg()
    local tbFile = LoadCsv("resource/resource_amend/amend_Sequence.txt", 1)
    for _, tbLine in pairs(tbFile) do
        local sOriginal_Path = tbLine.Original_Path
        local s18ban_path = tbLine['18ban_path']
        local tbGDPL = Eval(tbLine.GDPL)

        if sOriginal_Path then
            ResourceAmend.tbAmendSequence[sOriginal_Path] = {s18ban_path = s18ban_path, tbGDPL = tbGDPL}
        end
    end
    print('Load ../resource/resource_amend/amend_Sequence.txt')
end

---加载模型资源
function ResourceAmend.LoadAmend3DCfg()
    local tbFile = LoadCsv("resource/resource_amend/amend_3D.txt", 1)
    for _, tbLine in pairs(tbFile) do
        local sOriginal_Path = tbLine.Original_Path
        local s18ban_path = tbLine['18ban_path']
        local tbGDPL = Eval(tbLine.GDPL)

        if sOriginal_Path then
            ResourceAmend.tbAmend3D[sOriginal_Path] = {s18ban_path = s18ban_path, tbGDPL = tbGDPL}
        end
    end
    print('Load ../resource/resource_amend/amend_3D.txt')
end

---加载模型资源
function ResourceAmend.LoadAmendAudio()
    local tbFile = LoadCsv("resource/resource_amend/amend_Audio.txt", 1)
    for _, tbLine in pairs(tbFile) do
        local nOriginal_Path = tonumber(tbLine.Original_Path)
        local n18ban_path = tonumber(tbLine['18ban_path'])
        local tbGDPL = Eval(tbLine.GDPL)

        if nOriginal_Path then
            ResourceAmend.tbAmendAudio[nOriginal_Path] = {n18ban_path = n18ban_path, tbGDPL = tbGDPL}
        end
    end
    print('Load ../resource/resource_amend/amend_Audio.txt')
end

ResourceAmend.LoadAmend2DCfg()
ResourceAmend.LoadAmendSpineCfg()
ResourceAmend.LoadAmendSequenceCfg()
ResourceAmend.LoadAmend3DCfg()
ResourceAmend.LoadAmendAudio()
ResourceAmend.LoadAmendCGSpine()

ResourceAmend.ReadLocalFlag()

function ResourceAmend.UpdateAmendFlag()
    if not me then return end
    local nFlag = me:GetGlobalAttr('SKIN_AMEND_SWITCH')
    ResourceAmend.bOpenAmend = nFlag > 0
    print('ResourceAmend.UpdateAmendFlag ->', nFlag)
end

function ResourceAmend.IsShield()
    if not me then return true end
    local nSelfShieldFlag = 0
    -- local nSelfShieldFlag = me:GetAttribute(ResourceAmend.GID, ResourceAmend.SID_BLACK)

    if nSelfShieldFlag > 0 then
        return true
    end

    local nGlobalShieldTimeStart = me:GetGlobalAttr('LOCALIZATION_TIME_SWITCH')
    local nGlobalShieldTimeEnd = me:GetGlobalAttr('LOCALIZATION_TIME_OVER_SWITCH')

    ---未开启时间屏蔽
    if nGlobalShieldTimeStart == 0 and nGlobalShieldTimeEnd == 0 then
        return false
    end

    local nCreateTime = me:CreateTime()
    --没有配置结束时间
    if nGlobalShieldTimeEnd == 0 then
        ---屏蔽配置时间之后的玩家
        if nCreateTime > nGlobalShieldTimeStart then
            return true
        end
    else
        ---屏蔽在时间段的玩家
        if nCreateTime > nGlobalShieldTimeStart and nCreateTime < nGlobalShieldTimeEnd then
            return true
        end
    end
    return false
end

EventSystem.On(Event.OnGlobalAttrs, function()
    ResourceAmend.UpdateAmendFlag()
end)

EventSystem.On(Event.Logined, function(bReconnected, bNeedRename)
    if me then
        me:SetGlobalAttr("BUTTOCK_SWITCH", 0)
        me:SetGlobalAttr("BREASTS_SWITCH", 0)
        me:SetGlobalAttr("AGE_PROTECT_LEVEL", 0)
        me:SetGlobalAttr("SKIN_AMEND_SWITCH", 0)
        me:SetGlobalAttr("LOCALIZATION_TIME_SWITCH", 0)
        me:SetGlobalAttr("LOCALIZATION_TIME_OVER_SWITCH", 0)
    end

    if bReconnected then return end
    ResourceAmend.tbCacheTime = {}
    ResourceAmend.UpdateAmendFlag()
    
    ResourceAmend.bServerShield = ResourceAmend.IsShield()
    if ResourceAmend.bServerShield then
        ResourceAmend.bNegated = false
    else
        ResourceAmend.ReadLocalFlag()
    end
    print('ResourceAmend : Shield', ResourceAmend.bServerShield, ResourceAmend.bNegated)
end)
