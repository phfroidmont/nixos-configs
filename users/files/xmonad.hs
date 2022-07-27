import System.Exit
import Data.Maybe (Maybe, isNothing, fromJust)
import qualified Data.List as L
import qualified Data.Map as M
import GHC.IO.Handle
-- Xmonad Core
import XMonad
import qualified XMonad.StackSet as W
import XMonad.Config.Desktop
import XMonad.Config.Azerty

-- Layouts
import XMonad.Layout.LayoutModifier
import XMonad.Layout.Gaps
import XMonad.Layout.Spacing
import XMonad.Layout.MultiToggle
import XMonad.Layout.NoBorders
import XMonad.Layout.MultiToggle.Instances
import XMonad.Layout.ResizableTile
import XMonad.Layout.BinarySpacePartition
import XMonad.Layout.SimpleFloat
import XMonad.Layout.PerWorkspace (onWorkspace)
import XMonad.Layout.Minimize
import XMonad.Layout.Fullscreen 

-- Actions
import XMonad.Actions.Navigation2D
import XMonad.Actions.GridSelect
import XMonad.Actions.UpdatePointer
import XMonad.Actions.SpawnOn
import XMonad.Actions.CycleWS

-- Hooks
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.ManageDocks

-- Utils
import XMonad.Util.NamedScratchpad
import XMonad.Util.WorkspaceCompare
import XMonad.Util.Run
import XMonad.Util.EZConfig

myTerminal = "alacritty"
mySelectScreenshot = "scrot -s"
myScreenshot = "scrot"

myWorkspaces = ["1","2","3","4","5","6"] ++ map show [7..9]
myModMask = mod4Mask

myFocusFollowsMouse :: Bool
myFocusFollowsMouse = True

main = do
    xmproc <- spawnPipe "xmobar .xmonad/xmobarrc"
    xmonad $ docks $ myConfig xmproc

myConfig xmproc = azertyConfig {
    terminal            = myTerminal,
    focusFollowsMouse   = True,
    borderWidth         = 1,
    modMask             = mod4Mask,
    workspaces          = myWorkspaces,
    normalBorderColor   = "#474646",
    focusedBorderColor  = "#83a598",
    layoutHook          = myLayout,
    manageHook          = manageDocks <+> (isFullscreen --> doFullFloat) <+> manageHook defaultConfig,
    --handleEventHook     = myEventHook <+> handleEventHook defaultConfig,
    logHook             = (myLogHook xmproc) <+> logHook defaultConfig,
    --keys                = \c -> mkKeymap c myAdditionalKeys,
    startupHook         = myStartupHook xmproc
} `removeKeysP` myRemoveKeys `additionalKeysP` myAdditionalKeys

myLogHook xmproc = dynamicLogWithPP xmobarPP {
    ppOutput    = hPutStrLn xmproc,
    ppCurrent = xmobarColor "#83a598" "" . wrap "[" "]",   -- #9BC1B2 #69DFFA
    ppTitle = xmobarColor "#d3869b" "" . shorten 100,       -- #9BC1B2 #69DFFA
    ppSort = fmap (.namedScratchpadFilterOutWorkspace) getSortByTag
    --ppLayout = xmobarColor "#fabd2f" "" . myIcons
} >> updatePointer (0.75, 0.75) (0.75, 0.75)

myRemoveKeys = [
    ]

myAdditionalKeys = [
    ("M-q", kill),
    ("M-x", spawn "i3lock -e -f -c 000000 -i ~/.wallpaper.png"),
    ("M-S-h", sendMessage (IncMasterN 1)),
    ("M-S-l", sendMessage (IncMasterN (-1))),
    ("M-S-<Return>", windows W.swapMaster),
    ("M-d", spawn "rofi -show run"),
    ("M-s", spawn "rofi -show ssh"),
    ("M-w", spawn "firefox"),
    ("M-i", spawn $ myTerminal ++ " -e htop"),
    ("M-e", spawn $ myTerminal ++ " -e neomutt"),
    ("M-r", spawn $ myTerminal ++ " -e ranger"),
    ("M-y", spawn $ myTerminal ++ " -e calcurse"),
    ("M-v", spawn $ myTerminal ++ " -e ncmpcpp -s visualizer"),
    ("M-m", spawn $ myTerminal ++ " -e ncmpcpp"),
    ("M-n", spawn $ myTerminal ++ " -e newsboat"),
    ("M-c", spawn $ myTerminal ++ " -e weechat"),
    ("<Print>", spawn "scrot -e 'mv $f ~/Pictures/Screenshots'"),
    ("S-<Print>", spawn "~/.xmonad/scripts/screenshot.sh"),
    ("M-S-a", spawn $ myTerminal ++ " -e pulsemixer"),
    ("M-<Return>", spawn myTerminal),
    ("M-f", sendMessage $ Toggle FULL),
    -- Switch workspaces and screens
    --("M-<Right>", moveTo Next (WSIs hiddenNotNSP)),
    --("M-<Left>", moveTo Prev (WSIs hiddenNotNSP)),
    --("M-S-<Right>", shiftTo Next (WSIs hiddenNotNSP)),
    --("M-S-<Left>", shiftTo Prev (WSIs hiddenNotNSP)),
    ("M-<Down>", nextScreen),
    ("M-<Up>", prevScreen),
    ("M-S-<Down>", shiftNextScreen),
    ("M-S-<Up>", shiftPrevScreen),
    ("M-S-r", spawn "xmonad --recompile; xmonad --restart"),
    ("<XF86AudioLowerVolume>"        ,spawn "pulsemixer --change-volume -1"),
    ("<XF86AudioRaiseVolume>"        ,spawn "pulsemixer --change-volume +1"),
    ("<XF86AudioMute>"               ,spawn "pulsemixer --toggle-mute"),
    ("<XF86MonBrightnessDown>"       ,spawn "xbacklight -dec 5"),
    ("<XF86MonBrightnessUp>"         ,spawn "xbacklight -inc 5"),
    ("<XF86AudioPlay>"               ,spawn "mpc toggle"),
    ("M-p"                           ,spawn "mpc toggle"),
    ("<XF86AudioPrev>"               ,spawn "mpc prev"),
    ("<XF86AudioNext>"               ,spawn "mpc next"),
    ("<XF86Sleep>"                   ,spawn "systemctl suspend")
    ]

myLayout = smartSpacing 5
	$ smartBorders
        $ mkToggle (NOBORDERS ?? FULL ?? EOT)
        $ avoidStruts
        $ layoutHook defaultConfig

myStartupHook xmproc = do
    setWMName "LG3D"
    spawn "feh --no-fehbg --bg-fill ~/.wallpaper.png"
    return () >> checkKeymap (myConfig xmproc) myAdditionalKeys
