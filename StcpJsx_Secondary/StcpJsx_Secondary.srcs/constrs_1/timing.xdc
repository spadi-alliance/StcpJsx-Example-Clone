# Clock definition
create_clock -period 10.000 -name clk_osc -waveform {0.000 5.000} [get_ports BASE_CLKP]
create_clock -period 8.000 -name clk_gmod -waveform {0.000 4.000} [get_pins BUFG_modclk/O]

#create_clock -period 8 -name clk_mod -waveform {0.000 4.000} [get_pins u_cbtlane/BUFG_modclk/O]
#create_clock -period 10 -name clk_mod -waveform {0.000 5.000} [get_pins u_cbtlane/BUFG_modclk/O]
#set_input_jitter clk_b2tt 0.100

#set_clock_groups -name async_input -physically_exclusive -group [get_clocks clk_osc] -group [get_clocks clk_hul]

#create_clock -period 1.600 -name clk_fast -waveform {0.000 0.800} [get_ports CLK_FASTP]
#set_input_jitter clk_fast 0.030

#create_clock -period 8.000 -name clk_slow -waveform {0.000 4.000} [get_ports CLK_SLOWP]
#set_input_jitter clk_slow 0.030

#set_case_analysis 0 [get_pins BUFGMUX_C6C_inst/S]
#set_case_analysis 1 [get_pins BUFGMUX_FAST_inst/S]
#set_case_analysis 1 [get_pins BUFGMUX_SLOW_inst/S]

# SiTCP
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX11Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX12Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX13Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX14Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX15Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX16Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX17Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX18Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX19Data*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX1AData*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX1BData*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/BBT_SiTCP_RST/resetReq*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/GMII/GMII_TXBUF/memRdReq*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/GMII/GMII_TXBUF/orRdAct*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/GMII/GMII_TXBUF/dlyBank0LastWrAddr*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/GMII/GMII_TXBUF/dlyBank1LastWrAddr*}]
set_false_path -through [get_nets {gen_SiTCP[*].u_SiTCP_Inst/SiTCP/GMII/GMII_TXBUF/muxEndTgl}]

#set_false_path -from [get_nets u_MTX1/reg_fbh*] -to [get_nets u_MTX1/gen_tof[*].gen_ch[*].u_Matrix_Impl/in_fbh]

create_generated_clock -name clk_sys [get_pins u_ClkMan_Inst/inst/mmcm_adv_inst/CLKOUT0]
create_generated_clock -name clk_indep [get_pins u_ClkMan_Inst/inst/mmcm_adv_inst/CLKOUT1]
create_generated_clock -name clk_spi [get_pins u_ClkMan_Inst/inst/mmcm_adv_inst/CLKOUT2]
create_generated_clock -name clk_icap [get_pins u_ClkMan_Inst/inst/mmcm_adv_inst/CLKOUT3]
create_generated_clock -name clk_idctrl [get_pins u_ClkMan_Inst/inst/mmcm_adv_inst/CLKOUT4]

create_generated_clock -name clk_gmii1 [get_pins u_GtClockDist_Inst/core_clocking_i/mmcm_adv_inst/CLKOUT0]
create_generated_clock -name clk_gmii2 [get_pins u_GtClockDist_Inst/core_clocking_i/mmcm_adv_inst/CLKOUT1]

#create_generated_clock -name mmcm_fast [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT0]
#create_generated_clock -name mmcm_slow [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT1]

#create_generated_clock -name clk_mig_ui [get_pins u_MIG/u_mig_7series_0/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKFBOUT]
#create_generated_clock -name clk_mig_ui_out0 [get_pins u_MIG/u_mig_7series_0/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKOUT0]

#create_generated_clock -name clk_gmii1   [get_pins gen_pcspma[0].u_pcspma_Inst/core_support_i/core_clocking_i/mmcm_adv_inst/CLKOUT0]
#create_generated_clock -name clk_gmii2   [get_pins gen_pcspma[1].u_pcspma_Inst/core_support_i/core_clocking_i/mmcm_adv_inst/CLKOUT0]

#create_generated_clock -name clk_base     [get_pins u_ClkTdc_Inst/inst/plle2_adv_inst/CLKOUT0]
#create_generated_clock -name clk_tdc0     [get_pins u_ClkTdc_Inst/inst/plle2_adv_inst/CLKOUT1]
#create_generated_clock -name clk_tdc90    [get_pins u_ClkTdc_Inst/inst/plle2_adv_inst/CLKOUT2]
#create_generated_clock -name clk_tdc180   [get_pins u_ClkTdc_Inst/inst/plle2_adv_inst/CLKOUT3]
#create_generated_clock -name clk_tdc270   [get_pins u_ClkTdc_Inst/inst/plle2_adv_inst/CLKOUT4]

#set_multicycle_path -setup -from [get_clocks clk_tdc270] -to [get_clocks clk_tdc0] 2

#cslin
#set_clock_groups -name async_sys_gmii -asynchronous -group clk_sys -group {clk_gmii1 clk_gmii2} -group clk_indep -group clk_spi -group clk_icap -group {clk_fast clk_slow} -group clk_idctrl
#    -group clk_mig
#create_generated_clock -name clk_fast [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT0]
#create_generated_clock -name clk_slow [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT1]
#create_generated_clock -name clk_base [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT2]
#create_generated_clock -name clk_tdc0 [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT3]
#create_generated_clock -name clk_tdc90 [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT4]
#create_generated_clock -name clk_tdc180 [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT5]
#create_generated_clock -name clk_tdc270 [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT6]

create_generated_clock -name clk_fast [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT0]
create_generated_clock -name clk_slow [get_pins u_CdcmMan_Inst/inst/mmcm_adv_inst/CLKOUT1]

set_clock_groups -name async_sys_gmii -asynchronous -group clk_sys -group {clk_gmii1 clk_gmii2} -group clk_indep -group clk_spi -group clk_icap -group clk_idctrl -group {clk_fast clk_slow}
#set_clock_groups -asynchronous -group {clk_sys}
#set_clock_groups -asynchronous -group {clk_gmii1 clk_gmii2}
#set_clock_groups -asynchronous -group {clk_indep}
#set_clock_groups -asynchronous -group {clk_spi}
#set_clock_groups -asynchronous -group {clk_icap}
#set_clock_groups -asynchronous -group {clk_idctrl}
#set_clock_groups -asynchronous -group {clk_fast clk_slow clk_tdc0 clk_tdc1 clk_tdc2 clk_tdc3}

#set_clock_groups -name async_sys_indep -asynchronous -group clk_sys
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_b2tt_raw]

set_false_path -through [get_ports {LED[1]}]
set_false_path -through [get_ports {LED[2]}]
set_false_path -through [get_ports {LED[3]}]
set_false_path -through [get_ports {LED[4]}]

#set_false_path -through [get_nets u_BCT_Inst/rst_from_bus]





