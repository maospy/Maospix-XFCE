-- maospix: las aplicaciones se abren maximizadas.
-- Para desactivarlo: borrar este archivo (o quitar devilspie2 en Sesión e inicio).
local excluir = {
  ["maospix-clima"] = true, ["xfce4-appfinder"] = true, ["xfce4-notifyd"] = true,
  ["wrapper-2.0"] = true, ["xfdesktop"] = true, ["xfce4-panel"] = true,
  ["pavucontrol"] = true, ["blueman-manager"] = true, ["nm-connection-editor"] = true,
  ["xfce4-screenshooter"] = true, ["xfce4-taskmanager"] = true,
  ["calamares"] = true,
}
local clase = string.lower(get_class_instance_name() or "")
local grupo = string.lower(get_window_class() or "")
if get_window_type() == "WINDOW_TYPE_NORMAL" and not excluir[clase] and not excluir[grupo] then
  maximize()
end
