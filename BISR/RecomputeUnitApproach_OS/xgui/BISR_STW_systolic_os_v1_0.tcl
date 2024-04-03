# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "COLS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ROWS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WORD_SIZE" -parent ${Page_0}


}

proc update_PARAM_VALUE.COLS { PARAM_VALUE.COLS } {
	# Procedure called to update COLS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.COLS { PARAM_VALUE.COLS } {
	# Procedure called to validate COLS
	return true
}

proc update_PARAM_VALUE.ROWS { PARAM_VALUE.ROWS } {
	# Procedure called to update ROWS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ROWS { PARAM_VALUE.ROWS } {
	# Procedure called to validate ROWS
	return true
}

proc update_PARAM_VALUE.WORD_SIZE { PARAM_VALUE.WORD_SIZE } {
	# Procedure called to update WORD_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WORD_SIZE { PARAM_VALUE.WORD_SIZE } {
	# Procedure called to validate WORD_SIZE
	return true
}


proc update_MODELPARAM_VALUE.ROWS { MODELPARAM_VALUE.ROWS PARAM_VALUE.ROWS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ROWS}] ${MODELPARAM_VALUE.ROWS}
}

proc update_MODELPARAM_VALUE.COLS { MODELPARAM_VALUE.COLS PARAM_VALUE.COLS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.COLS}] ${MODELPARAM_VALUE.COLS}
}

proc update_MODELPARAM_VALUE.WORD_SIZE { MODELPARAM_VALUE.WORD_SIZE PARAM_VALUE.WORD_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WORD_SIZE}] ${MODELPARAM_VALUE.WORD_SIZE}
}

