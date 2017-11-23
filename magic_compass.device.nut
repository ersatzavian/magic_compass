//https://github.com/electricimp/LSM9DS0/tree/v1.1
#require "LSM9DS0.class.nut:1.1.0"

// L6470 "dSPIN" stepper motor driver IC
// http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/CD00255075.pdf
// The following constants are all associated with the L6470 class
// these are consts outside the class so that we can use them in motor configuration
// and for performance reasons
const CONFIG_PWMDIV_1      = 0x0000;
const CONFIG_PWMDIV_2      = 0x2000;
const CONFIG_PWMDIV_3      = 0x4000;
const CONFIG_PWMDIV_4      = 0x5000;
const CONFIG_PWMDIV_5      = 0x8000;
const CONFIG_PWMDIV_6      = 0xA000;
const CONFIG_PWMDIV_7      = 0xC000;
const CONFIG_PWMMULT_0_625 = 0x0000;
const CONFIG_PWMMULT_0_750 = 0x0400;
const CONFIG_PWMMULT_0_875 = 0x0800;
const CONFIG_PWMMULT_1_000 = 0x0C00;
const CONFIG_PWMMULT_1_250 = 0x1000;
const CONFIG_PWMMULT_1_500 = 0x1400;
const CONFIG_PWMMULT_1_750 = 0x1800;
const CONFIG_PWMMULT_2_000 = 0x1C00;
const CONFIG_SR_320        = 0x0000;
const CONFIG_SR_75         = 0x0100;
const CONFIG_SR_110        = 0x0200;
const CONFIG_SR_260        = 0x0300;
const CONFIG_INT_OSC       = 0x0000;
const CONFIG_OC_SD         = 0x0080;
const CONFIG_VSCOMP        = 0x0020;
const CONFIG_SW_USER       = 0x0010;
const CONFIG_EXT_CLK       = 0x0008;

const STEP_MODE_SYNC        = 0x80;
const STEP_SEL_FULL         = 0x00;
const STEP_SEL_HALF         = 0x01;
const STEP_SEL_1_4          = 0x02;
const STEP_SEL_1_8          = 0x03;
const STEP_SEL_1_16         = 0x04;
const STEP_SEL_1_32         = 0x05;
const STEP_SEL_1_64         = 0x06;
const STEP_SEL_1_128        = 0x06;

const CMD_NOP		 	          = 0x00;
const CMD_GOHOME		        = 0x70;
const CMD_GOMARK		        = 0x78;
const CMD_GOTO              = 0x60;
const CMD_GOTO_DIR          = 0x68;
const CMD_GOUNTIL           = 0x82;
const CMD_RESET_POS	        = 0xD8;
const CMD_RESET		          = 0xC0;
const CMD_RUN               = 0x50;
const CMD_SOFT_STOP	        = 0xB0;
const CMD_HARD_STOP	        = 0xB8;
const CMD_SOFT_HIZ		      = 0xA0;
const CMD_HARD_HIZ		      = 0xA8;
const CMD_GETSTATUS	        = 0xD0;	 
const CMD_GETPARAM          = 0x20;
const CMD_SETPARAM          = 0x00;

const REG_ABS_POS 		      = 0x01;
const REG_EL_POS 		        = 0x02;
const REG_MARK			        = 0x03;
const REG_SPEED		          = 0x04;
const REG_ACC			          = 0x05;
const REG_DEC			          = 0x06;
const REG_MAX_SPD 		      = 0x07;
const REG_MIN_SPD 		      = 0x08;
const REG_KVAL_HOLD 	      = 0x09;
const REG_KVAL_RUN 	        = 0x0A;
const REG_KVAL_ACC 	        = 0x0B;
const REG_KVAL_DEC 	        = 0x0C;
const REG_INT_SPD	  	      = 0x0D;
const REG_ST_SLP		        = 0x0E;
const REG_FN_SLP_ACC	      = 0x0F;
const REG_FN_SLP_DEC	      = 0x10;
const REG_K_THERM		        = 0x11;
const REG_ADC_OUT		        = 0x12;
const REG_OCD_TH		        = 0x13;
const REG_STALL_TH		      = 0x13;
const REG_STEP_MODE	        = 0x14;
const REG_FS_SPD		        = 0x15;
const REG_STEP_MODE 	      = 0x16;
const REG_ALARM_EN		      = 0x17;
const REG_CONFIG 		        = 0x18;
const REG_STATUS 		        = 0x19;

class L6470 {
  
	_spi 	  = null;
	_cs_l 	= null;
	_rst_l 	= null;
	_flag_l	= null;
	
	constructor(spi, cs_l, rst_l = null, flag_l = null, flag_l_cb = null) {
		this._spi 	  = spi;
		this._cs_l 	  = cs_l;
		this._rst_l 	= rst_l;
		this._flag_l  = flag_l;

		_cs_l.write(1);
		
		// hardware reset line is optional; don't attempt to write if not provided
		if (_rst_l) {
		  _rst_l.write(1);
		}
		
		// If flag pin exists, re-configure to assign callback
		if (flag_l_cb) {
  		_flag_l.configure(DIGITAL_IN, handleFlag.bindenv(this));
		}
		
		reset();
	}
	
	// helper function: read up to four bytes from the device
	// no registers in the L6470 are more than four bytes wide
	// returns an integer
	function _read(num_bytes) {
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        _cs_l.write(0);
	        result += ((spi.writeread(format("%c",CMD_NOP))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        _cs_l.write(1);
	    }
	    return result;
	}
	
	// helper function: write an arbitrary length value to the device
	// Input: data as a string. Use format("%c",byte) to prepare to write with this function
	// Returns an string containing the data read back as this data is written out
	function _write(data) {
	    local num_bytes = data.len();
	    local result = 0;
	    for (local i = 0; i < num_bytes; i++) {
	        _cs_l.write(0);
	        result += ((spi.writeread(format("%c",data[i]))[0].tointeger() & 0xff) << (8 * (num_bytes - 1 - i)));
	        _cs_l.write(1);
	    }
	    return result;
	}
	
	// Use the hardware reset line to reset the controller
	// Blocks for 1 ms while pulsing the reset line
	// If reset line is not provided to constructor, soft Reset is used.
	// Input: None
	// Return: None
	function reset() {
	  if (!_rst_l) {
	    softReset();
	    return;
	  }
	  _rst_l.write(0);
		imp.sleep(0.001);
		_rst_l.write(1);
		imp.sleep(0.001);
		
		// device comes out of reset with overcurrent bit set in status register
    // read the register to clear the bit.
    getStatus();
	}
	
  // Use the reset command to reset the controler
  // Input: None
  // Return: None
	function softReset() {
		_write(format("%c", CMD_RESET));
		
		// device comes out of reset with overcurrent bit set in status register
    // read the register to clear the bit.
    getStatus();
	}
	
	// read the L6470 status register
	// Input: None
	// Return: 2-byte status register value (integer)
	function getStatus() {
		_write(format("%c", CMD_GETSTATUS));
		return _read(2);
	}
	
	// read the state of the BUSY bit in the L6470 status register
	// Input: None
	// Return: 1 if busy, 0 otherwise.
	function isBusy() {
	  if (getStatus() & 0x0002) { return 0; }
	  return 1;
	}
	
	// write the L6470 config register
	// Input: new 2-byte value (integer)
	// Return: None
	function setConfig(val) {
	  _write(format("%c", CMD_SETPARAM | REG_CONFIG));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the L6470 config register
	// Input: None
	// Return: 2-byte config register value (integer)
	function getConfig() {
	  _write(format("%c", CMD_GETPARAM | REG_CONFIG));
		return _read(2);
	}
	
	// configure the microstepping mode
	// OR STEP_MODE consts together to generate new value
	// Input: New (1-byte) step mode (integer)
	// Return: None
	function setStepMode(val) {
	  _write(format("%c", CMD_SETPARAM | REG_STEP_MODE));
	  _write(format("%c", (val & 0xff)));
	}
	
	// read the current microstepping mode
	// Input: None
	// Return: step divisor (1, 2, 4, 8, 16, 32, 64, or 128), or 0 for Sync mode. Returns -1 on error.
	function getStepMode() {
	  _write(format("%c", CMD_GETPARAM | REG_STEP_MODE));
	  local mode = _read(1);
	  switch (mode) {
	    case STEP_MODE_SYNC:
	      return 0;
	    case STEP_SEL_FULL:
	      return 1;
	    case STEP_SEL_HALF:
	      return 2;
	    case STEP_SEL_1_4:
	      return 4;
	    case STEP_SEL_1_8:
	      return 8;
	    case STEP_SEL_1_16:
	      return 16;
	    case STEP_SEL_1_32:
	      return 32;
	    case STEP_SEL_1_64:
	      return 64;
	    case STEP_SEL_1_128:
	      return 128;
	    default:
	      return -1;
	  }
	}
	
	// set the minimum motor speed in steps per second
	// this will generate different angular speed depending on the number of steps per rotation in your motor
	// device comes out of reset with min speed set to zero
	// Input: new min speed in steps per second (integer)
	// Return: None
	function setMinSpeed(stepsPerSec) {
	  // min speed (steps/s) = (MIN_SPEED * 2^-24 / tick (250 ns))
	  local val = math.ceil(stepsPerSec * 4.194304).tointeger();
	  if (val > 0x1FFF) { val = 0x1FFF; }
	  _write(format("%c", CMD_SETPARAM | REG_MIN_SPD));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	
	// read the current minimum speed setting
	// Input: None
	// Return: Min speed in steps per second (integer)
	function getMinSpeed() {
	  _write(format("%c", CMD_GETPARAM | REG_MIN_SPD));
		local minspeed = _read(2) & 0x1FFF;
		minspeed = math.ceil((1.0 * minspeed) / 4.194304);
		return minspeed;
	}
	
	// set the maximum motor speed in steps per second
	// this will generate different angular speed depending on the number of steps per rotation in your motor
	// Input: new max speed in steps per second (integer)
	// Return: None
	function setMaxSpeed(stepsPerSec) {
	  // max speed (steps/s) = (MAX_SPEED * 2^-28 / tick (250ns))
	  local val = math.ceil(stepsPerSec * 0.065536).tointeger();
	  if (val > 0x03FF) { val = 0x03FF; }
	  _write(format("%c", CMD_SETPARAM | REG_MAX_SPD));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the current maximum speed setting
	// Input: None
	// Return: Max speed in steps per second (integer)
	function getMaxSpeed() {
	  _write(format("%c", CMD_GETPARAM | REG_MAX_SPD));
		local maxspeed = _read(2) & 0x03FF;
		maxspeed = math.ceil((1.0 * maxspeed) / 0.065536);
		return maxspeed;
	}
	
	// set the full-step motor speed in steps per second
	// Input: new full-step speed in steps per second (integer)
	// Return: None
	function setFSSpeed(stepsPerSec) {
	  // fs_speed (steps/s) = ((FS_SPD + 0.5) * 2^-18) / tick (250ns))
	  local val = math.ceil((stepsPerSec * 0.065536) - 0.5).tointeger();
	  if (val > 0x03FF) { val = 0x03FF; }
	  _write(format("%c", CMD_SETPARAM | REG_FS_SPD));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// read the current full-step speed setting
	// Input: None
	// Return: full-step speed in steps per second (integer)
	function getFSSpeed() {
	  _write(format("%c", CMD_GETPARAM | REG_FS_SPD));
		local fsspeed = _read(2) & 0x03FF;
		fsspeed = math.ceil(((1.0 * fsspeed) / 0.065536) + 7.629395);
		return fsspeed;
	}
	
	// set max acceleration in steps/sec^2
	// Input: integer
	// Return: None.
	function setAcc(stepsPerSecPerSec) {
	  local val = math.ceil(stepsPerSecPerSec * 0.137438).tointeger();
    if (val > 0x0FFF) { val = 0x0FFF; }
	  _write(format("%c", CMD_SETPARAM | REG_ACC));
	  _write(format("%c%c", ((val & 0xff00) >> 8), (val & 0xff)));
	}
	
	// set overcurrent threshold value
	// thresholds are set at 375 mA intervals from 375 mA to 6A
	// Input: threshold in mA (integer)
	// Return: None
	function setOcTh(threshold) {
	  local val = math.floor(threshold / 375).tointeger();
    if (val > 0x0f) { val = 0x0f; }
	  _write(format("%c", CMD_SETPARAM | REG_OCD_TH));
	  _write(format("%c", (val & 0xff)));
	}
	
	// Set Supply Voltage Multiplier for hold state
	// Controller will apply a sinusoidal voltage of magnitude up to Vsupply * KVal
	// to the motor. 
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None
	function setHoldKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_HOLD));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for hold state
	// Input: None
	// Return: current hold-state supply voltage multiplier (0 to 1, float)
	function getHoldKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_HOLD));
	  return _read(1) / 256.0;
	}
	
	// Set Supply Voltage Multiplier for run state
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None
	function setRunKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_RUN));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for run state
	// Input: None
	// Return: current run-state supply voltage multiplier (0 to 1, float)
	function getRunKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_RUN));
	  return _read(1) / 256.0;
	}
	
	// Set Supply Voltage Multiplier for acceleration state
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None	
	function setAccKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_ACC));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for acceleration state
	// Input: None
	// Return: current accel-state supply voltage multiplier (0 to 1, float)
	function getAccKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_ACC));
	  return _read(1) / 256.0;
	}	

	// Set Supply Voltage Multiplier for deceleration state
	// Input: new Vsupply multiplier (0 to 1, float)
	// Return: None	
	function setDecKval(val) {
	  if (val > 256) { val = 256; }
	  if (val < 0) { val = 0; }
	  local kval_int = val * 256.0;
	  _write(format("%c", CMD_SETPARAM | REG_KVAL_DEC));
	  _write(format("%c", (kval_int.tointeger() & 0xff)));
	}
	
	// Get Supply Voltage Multiplier for deceleration state
	// Input: None
	// Return: current accel-state supply voltage multiplier (0 to 1, float)
	function getDecKval() {
	  _write(format("%c", CMD_GETPARAM | REG_KVAL_DEC));
	  return _read(1) / 256.0;
	}
	
	// Enable or Disable Low-speed position optimization. 
	// This feature reduces phase current crossover distortion and improves position tracking at low speed
	// See datasheet section 7.3
	// When enabled, min speed is forced to zero.
	// Input: bool 
	// Return: None
	function setLspdPosOpt(en) {
	  if (en) {
	    en = 1;
	  } else {
	    en = 0;
	  }
	  local mask = en << 12;
	  server.log(format("0x%02X", mask));
	  // get the MIN_SPEED reg contents and mask the LSPD_OPT bit in
	  _write(format("%c", CMD_GETPARAM | REG_MIN_SPD));
	  local data = ((_read(2) & 0x1fff) & ~mask) | mask;
	  server.log(format("0x%X", data));
    _write(format("%c%c%c", CMD_SETPARAM | REG_MIN_SPD, (data & 0x1f00 >> 8), data & 0xff));
	}
	
	// Determine whether low-speed position optimization is enabled. 
	// Input: None
	// Return: 1 if enabled, 0 otherwise
	function getLspdPosOpt() {
	  _write(format("%c", CMD_GETPARAM | REG_MIN_SPD));
	  local mask = 1 << 12;
	  local data = _read(2);
	  server.log(format("0x%X", data));
	  return (data & 0x1fff) & mask;
	}
	
	// Set current motor absolute position counter
	// unit value is equal to the current step mode (full, half, quarter, etc.)
	// position range is -2^21 to (2^21) - 1 microsteps
	// Input: 22-bit absolute position counter value (integer)
	// Return: None
	function setAbsPos(pos) {
    _write(format("%c%c%c%c", CMD_SETPARAM | REG_ABS_POS, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Get current motor absolute position counter
	// unit value is equal to the current step mode (full, half, quarter, etc.)
	// position range is -2^21 to (2^21) - 1 microsteps
	// Input: None
	// Return: 22-bit value (integer)
	function getAbsPos() {
	  _write(format("%c", CMD_GETPARAM | REG_ABS_POS));
	  return _read(3);
	}
	
	// Set current motor electrical position 
	// Motor will immediately move to this electrical position
	// Electrical position is a 9-bit value
	// Bits 8 and 7 indicate the current step
	// Bits 6:0 indicate the current microstep
	// Input: new electrical position value (integer)
	// Return: None
	function setElPos(pos) {
    _write(format("%c%c%c", CMD_SETPARAM | REG_EL_POS, (pos & 0x0100) >> 8, pos & 0xff));
	}
	
	// Get current motor electrical position 
	// Input: None
	// Return: current 9-bit electrical position value (integer)
	function getElPos() {
	  _write(format("%c", CMD_GETPARAM | REG_EL_POS));
	  return _read(2);
	}
	
	// Set the absolute position mark register
	// Mark is a 22-bit value
	// Units match the current step unit (full, half, quarter, etc.)
	// Values range from -2^21 to (2^21) - 1 in microsteps
	// Input: New 22-bit position mark value (integer)
	// Return: None
	function setMark(pos) {
    _write(format("%c%c%c%c", CMD_SETPARAM | REG_MARK, (pos & 0xff0000) >> 16, (pos & 0xff00) >> 8, pos & 0xff));
	}
	
	// Get the absolute position mark register
	// Input: None
	// Return: 22-bit position mark value (integer)
	function getMark() {
	  _write(format("%c", CMD_GETPARAM | REG_MARK));
	  return _read(3);
	}

    // Immediately disable the power bridges and set the coil outputs to high-impedance state
    // This will raise the HiZ flag, if enabled
    // This command holds the BUSY line low until the motor is stopped
    // Input: None
    // Return: None
	function hardHiZ() {
	  _write(format("%c", CMD_HARD_HIZ));
	}
	
	// Decelerate the motor to zero, then disable the power bridges and set the 
	// coil outputs to high-impedance state
	// The HiZ flag will be raised when the motor is stopped
	// This command holds the BUSY line low until the motor is stopped
	// Input: None
	// Return: None
	function softHiZ() {
	  _write(format("%c", CMD_SOFT_HIZ));
	}
	
    // Move the motor immediately to the HOME position (zero position marker)
    // The motor will take the shortest path
    // This is equivalent to using GoTo(0) without a direction
    // If a direction is mandatory, use GoTo and specify a direction
    // Input: None
    // Return: None
	function goHome() {
	  _write(format("%c", CMD_GOHOME));
	}
	
	// Move the motor immediately to the MARK position
	// MARK defaults to zero
	// Use setMark to set the mark position register
	// The motor will take the shortest path to the MARK position
	// If a direction is mandatory, use GoTo and specify a direction
	// Input: None
	// Return: None
	function goMark() {
	  _write(format("%c", CMD_GOMARK));
	}
	
	// Move the motor num_steps in a direction
	// if fwd = 1, the motor will move forward. If fwd = 0, the motor will step in reverse
	// num_steps is a 22-bit value specifying the number of steps; units match the current step mode.
	// Input: fwd (0 or 1), num_steps (integer)
	// Return: None
	function move(fwd, num_steps) {
	  local cmd = CMD_MOVE;
	  if (fwd) { cmd = CMD_RUN | 0X01; }
	  _write(format("%c%c%c%c", cmd, (num_steps & 0xff0000) >> 16, (num_steps & 0xff00) >> 8, num_steps & 0xff));
	}
	
	// Move the motor to a position
	// Position is in steps and may be floating-point. 
	// Class will convert this to a 22-bit value in the same units as the current stepping value.
	// Direction is 1 for forward, 0 for reverse
	// If a direction not provided, the motor will take the shortest path
	// Input: Position (integer), [direction (integer)]
  // Return: None
	function goTo(pos, dir = null) {
	  local cmd = CMD_GOTO;
	  if (dir != null) {
	    if (dir == 0) {
    	  cmd = CMD_GOTO_DIR;
	    } else {
	      cmd = CMD_GOTO_DIR | 0x01;
	    }
	  }
	  local step_mode = getStepMode();
	  if (step_mode < 1) { step_mode = 1; }
	  local pos_counts = (pos * step_mode).tointeger();
	  // get the current step 
    _write(format("%c%c%c%c", cmd, (pos_counts & 0x3f0000) >> 16, (pos_counts & 0xff00) >> 8, pos_counts & 0xff));
	}
	
	// Move the motor until the controller's switch line is pulled low
	// This automates setting the home position with a limit switch or hall sensor!
	// If the SW_MODE bit in the config reg is '0', the motor will hard-stop. 
	// If SW_MODE is '1', the motor will decelerate. 
	// When the motor is stopped, 
	// Input: 
	//  fwd (bool) - if true, run forward to the switch.
  //  speed (steps per second, integer) - defaults to max speed.
	//  set_mark_reg (bool) - if true, ABS_POS will be preserved and copied to the MARK register. Otherwise, ABS_POS will be zeroed.
	// Return: None
	function goUntil(fwd = 1, speed = null, set_mark_reg = 0) {
	  //server.log("running at speed = "+speed);
	  local cmd = CMD_GOUNTIL;
	  if (set_mark_reg) { cmd = cmd | 0x04; }
	  if (fwd) { cmd = cmd | 0x01; }
	  
	  // default to max speed (15650 steps/s)
	  local spd = 0x0fffff;
	  if (speed != null) {
	    // speed (steps/s) = SPEED * 2^-28/tick (250ns). Speed field is 20 bits.
	    spd = math.ceil(67.108864 * speed).tointeger();
	  }
	  
	  local spd_byte2 = (spd >> 16) & 0x0f;
	  local spd_byte1 = (spd >> 8) & 0xff;
	  local spd_byte0 = spd & 0xff;
	  //server.log(format("0x %02X %02X %02X %02X", cmd, spd_byte2, spd_byte1, spd_byte0));
	  _write(format("%c%c%c%c", cmd, spd_byte2, spd_byte1, spd_byte0));
	}
	
	// Run the motor
	// Direction is 1 for fwd, 0 for reverse
	// Speed is in steps per second. Angular speed will depend on the steps per rotation of your motor
	// Input: [direction (integer)], [speed (steps/s)]
	// Return: None
	function run(fwd = 1, speed = null) {
	  local cmd = CMD_RUN;
	  if (fwd) { cmd = CMD_RUN | 0x01; }
	  
	  // default to max speed (15650 steps/s)
	  local spd = 0x0fffff;
	  if (speed != null) {
	    // speed (steps/s) = SPEED * 2^-28/tick (250ns). Speed field is 20 bits.
	    spd = math.ceil(67.108864 * speed).tointeger();
	  }
	  
	  local spd_byte2 = (spd >> 16) & 0x0f;
	  local spd_byte1 = (spd >> 8) & 0xff;
	  local spd_byte0 = spd & 0xff;
    _write(format("%c%c%c", cmd, spd_byte2, spd_byte1, spd_byte0));
	}
	
	// Soft-stop the motor. This will decelerate the motor smoothly to zero speed.
	// Input: None
	// Return: None
	function stop() {
	  _write(format("%c", CMD_SOFT_STOP));
	}
}

// https://cdn.sparkfun.com/assets/parts/1/2/2/8/0/GlobalTop_Titan_X1_Datasheet.pdf
// https://cdn.sparkfun.com/assets/parts/1/2/2/8/0/GTOP_NMEA_over_I2C_Application_Note.pdf
class MT333X {

    // GGA: Time, position and fix type data.
    // GSA: GPS receiver operating mode, active satellites used in the
    //      position solution and DOP values.
    // GSV: The number of GPS satellites in view satellite ID numbers,
    //      elevation, azimuth, and SNR values.
    // RMC: Time, date, position, course and speed data. Recommended
    //      Minimum Navigation Information.
    // VTG: Course and speed information relative to the ground
    
    // different commands to set the update rate from once a second (1 Hz) to 10 times a second (10Hz)
    // Note that these only control the rate at which the position is echoed, to actually speed up the
    // position fix you must also send one of the position fix rate commands below too.
    static PMTK_SET_NMEA_UPDATE_100_MILLIHERTZ      = "$PMTK220,10000*2F"; // Once every 10 seconds, 100 millihertz.
    static PMTK_SET_NMEA_UPDATE_1HZ                 = "$PMTK220,1000*1F";
    static PMTK_SET_NMEA_UPDATE_5HZ                 = "$PMTK220,200*2C";
    static PMTK_SET_NMEA_UPDATE_10HZ                = "$PMTK220,100*2F";
    // Position fix update rate commands.
    static PMTK_API_SET_FIX_CTL_100_MILLIHERTZ      = "$PMTK300,10000,0,0,0,0*2C"; // Once every 10 seconds, 100 millihertz.
    static PMTK_API_SET_FIX_CTL_1HZ                 = "$PMTK300,1000,0,0,0,0*1C";
    static PMTK_API_SET_FIX_CTL_5HZ                 = "$PMTK300,200,0,0,0,0*2F";
    // Can't fix position faster than 5 times a second!
    
    static PMTK_SET_BAUD_115200                     = "$PMTK251,115200*1F";
    static PMTK_SET_BAUD_57600                      = "$PMTK251,57600*2C";
    static PMTK_SET_BAUD_9600                       = "$PMTK251,9600*17";
    
    // turn on only the second sentence (GPRMC)
    static PMTK_SET_NMEA_OUTPUT_RMCONLY             = "$PMTK314,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*29";
    // turn on GPRMC and GGA
    static PMTK_SET_NMEA_OUTPUT_RMCGGA              = "$PMTK314,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28";
    // turn on ALL THE DATA
    static PMTK_SET_NMEA_OUTPUT_ALLDATA             = "$PMTK314,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0*28";
    // turn off output
    static PMTK_SET_NMEA_OUTPUT_OFF                 = "$PMTK314,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28";
    
    // to generate your own sentences, check out the MTK command datasheet and use a checksum calculator
    // such as the awesome http://www.hhhh.org/wiml/proj/nmeaxor.html
    static PMTK_LOCUS_STARTLOG                      = "$PMTK185,0*22";
    static PMTK_LOCUS_STOPLOG                       = "$PMTK185,1*23";
    static PMTK_LOCUS_STARTSTOPACK                  = "$PMTK001,185,3*3C";
    static PMTK_LOCUS_QUERY_STATUS                  = "$PMTK183*38";
    static PMTK_LOCUS_ERASE_FLASH                   = "$PMTK184,1*22";
    static LOCUS_OVERLAP                            = 0;
    static LOCUS_FULLSTOP                           = 1;
    
    static PMTK_ENABLE_SBAS                         = "$PMTK313,1*2E";
    static PMTK_ENABLE_WAAS                         = "$PMTK301,2*2E";
    
    // standby command & boot successful message
    static PMTK_STANDBY                             = "$PMTK161,0*28";
    static PMTK_STANDBY_SUCCESS                     = "$PMTK001,161,3*36";  // Not needed currently
    static PMTK_AWAKE                               = "$PMTK010,002*2D";
    
    // ask for the release and version
    static PMTK_Q_RELEASE                           = "$PMTK605*31";
    
    // request for updates on antenna status 
    static PGCMD_ANTENNA                            = "$PGCMD,33,1*6C"; 
    static PGCMD_NOANTENNA                          = "$PGCMD,33,0*6D"; 
    
    static DEFAULT_BAUD  = 9600;
    static _VERBOSE = false;

    // pins and hardware
    _uart   = null;

    _uart_baud = null;
    _uart_buffer = "";
    
    // vars
    _last_pos_data = {};
    // TODO: add all keys to the pos data table in init routine so the class caller doesn't have to check if they exist
    
    _position_update_cb = null;
    _dop_update_cb      = null;
    _sats_update_cb     = null;
    _rmc_update_cb      = null;
    _vtg_update_cb      = null;
    _ant_status_update_cb = null;
    
    // -------------------------------------------------------------------------
    constructor(uart) {
        _uart   = uart;

        _uart_baud = DEFAULT_BAUD;
        _uart.configure(_uart_baud, 8, PARITY_NONE, 1, NO_CTSRTS, _uartCallback.bindenv(this));
    }
    
    // -------------------------------------------------------------------------
    function _sendCmd(cmdStr) {
        // TODO: Calculate checksums directly.
        _uart.write(cmdStr);
        _uart.write("\r\n");
        _uart.flush();
    }   
    
    // -------------------------------------------------------------------------
    // Parse a UTC timestamp from 
    // 064951.000 hhmmss.sss
    // Into
    // 06:09:51.000
    function _parseUTC(ts) {
        local result = "";
        result = result + (ts.slice(0,2)+ ":" + ts.slice(2,4) + ":" + ts.slice(4,ts.len()));
        return result;
    }
    
    // -------------------------------------------------------------------------
    // Parse a lat/lon coordinate from
    // 
    // ddmm.mmmm or dddmm.mmmm
    // returns coodinate in degrees as a floating-point number
    function _parseCoordinate(str) {
      local deg = 0;
      local min = 0;
      
      // degrees aren't justified with leading zeros
      // handle three-digit whole degrees
      if (split(str, ".")[0].len() == 4) {
        deg = str.slice(0,2).tointeger();  
        min = str.slice(2,str.len()).tofloat();
      } else {
        deg = str.slice(0,3).tointeger();
        min = str.slice(3,str.len()).tofloat();
      }
      
      local result = deg + min / 60.0;
      //server.log(str + "->" + deg + " deg, " + min + " min = " + result);
      return result;
    }
    
    // -------------------------------------------------------------------------
    function _uartCallback() {
        //server.log(_uart_buffer);
        _uart_buffer += _uart.readstring(80);
        local packets = split(_uart_buffer,"$");
        for (local i = 0; i < packets.len(); i++) {
            // make sure we can see the end of the packet before trying to parse
            if (packets[i].find("\r\n")) {
                try {
                    local len = packets[i].len()
                    _parse(packets[i]);
                    _uart_buffer = _uart_buffer.slice(len + 1,_uart_buffer.len());
                } catch (err) {
                  _uart_buffer = "";
                  if (_VERBOSE) {
                    server.log("[GPS] "+err+", Pkt: "+packets[i]);
                  }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    function _parse(packetstr_raw) {
        //server.log(packetstr_raw);
        // "PMTKxxxx" is a system command packet; ignore for now
        if (packetstr_raw.find("PMTK") != null) { return }
        packetstr_raw = split(strip(packetstr_raw),"*");
        local packetstr = packetstr_raw[0];
        //server.log("Parsing: "+packetstr);
        // TODO: Verify checksum
        local checksum = packetstr_raw[1];
        //server.log(checksum);
        
        // string split swallows repeated split characters, 
        // so workaround with string find for now
        //local fields = split(packetstr,",");
        local fields = [];
        local start = 0;
        local end = 0;
        do {
            end = packetstr.find(",",start);
            if (end != null) {
                fields.push(packetstr.slice(start,end));
                start = end+1;
            }
        } while (end != null);
        fields.push(packetstr.slice(start,packetstr.len()));
        
        local hdr = fields[0];
        switch (hdr) {
            // lots of cases, few commands
            // "GP-" = GPS
            // "GN-" = GLONASS
            // "GL-" = GPS + GLONASS
            case "GPGGA":
                _handleGGA(fields);
                break;
            case "GNGGA": 
                _handleGGA(fields);
                break;
            case "GPGSA":
                _handleGSA(fields);
                break;
            case "GNGSA":
                _handleGSA(fields);
                break;
            case "GLGSA":
                _handleGSA(fields);
                break;
            case "GPGSV":
                _handleGSV(fields);
                break;
            case "GLGSV":
                _handleGSV(fields);
                break;
            case "GNGSV":
                _handleGSV(fields);
                break;
            case "GPRMC":
                _handleRMC(fields);
                break;
            case "GNRMC":
                _handleRMC(fields);
                break;
            case "GPVTG":
                _handleVTG(fields);
                break;
            case "GNVTG":
                _handleVTG(fields);
                break;
            case "PGTOP":
                _handlePGTOP(fields)
                break;
            case "PGACK":
                // command ACK
                // TODO: Allow command callbacks to verify good ACK
                server.log("ACK: "+packetstr);
                break;
            default:
                if (_VERBOSE) {
                  server.log("[GPS] Unrecognized Header: "+packetstr);
                }
        }
    }   
    
    // -------------------------------------------------------------------------
    // Handle GxGGA packet: time, position, and fix data
    // Ex: "$GPGGA,064951.000,2307.1256,N,12016.4438,E,1,8,0.95,39.9,M,17.8,M,,*65 "
    // UTC Time 064951.000 hhmmss.sss
    function _handleGGA(fields) {
      _last_pos_data.time <- _parseUTC(fields[1]);
      // Latitude 2307.1256 ddmm.mmmm
      _last_pos_data.lat <- _parseCoordinate(fields[2]);
      // N/S Indicator N N=north or S=south
      _last_pos_data.ns <- fields[3];
      if (_last_pos_data.ns == "S") {
        _last_pos_data.lat = -1 * _last_pos_data.lat;
      }
      // Longitude 12016.4438 dddmm.mmmm
      _last_pos_data.lon <- _parseCoordinate(fields[4]);
      // E/W Indicator E E=east or W=west
      _last_pos_data.ew <- fields[5];
      if (_last_pos_data.ew == "W") {
        _last_pos_data.lon = -1 * _last_pos_data.lon;
      }
      // Position Fix
      _last_pos_data.fix <- fields[6];
      // Satellites Used 8 Range 0 to 14
      _last_pos_data.sats_used <- fields[7] ? fields[7].tointeger() : null;
      // HDOP 0.95 Horizontal Dilution of Precision
      _last_pos_data.hdop <- fields[8] != "" ? fields[8].tofloat() : null;
      // MSL Altitude 39.9 meters Antenna Altitude above/below mean-sea-level
      _last_pos_data.msl <- fields[9] != "" ? fields[9].tofloat() : null;
      // Units M meters Units of antenna altitude
      _last_pos_data.units_alt <- fields[10];
      // Geoidal Separation 17.8 meters
      _last_pos_data.geoidal_sep <- fields[11] != "" ? fields[11].tofloat() : null;
      // Units M meters Units of geoids separation
      _last_pos_data.units_sep <- fields[12];
      // Age of Diff. Corr. second Null fields when DGPS is not used
      _last_pos_data.diff_corr <- fields[13];
      
      if (_position_update_cb) _position_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    // Handle GxGSA Packet: DOP and Active Satellites Data
    // Ex: "$GPGSA,A,3,29,21,26,15,18,09,06,10,,,,,2.32,0.95,2.11*00 "
    // "M" = manual (forced into 2D or 3D mode)
    // "A" = 2C Automatic, allowed to auto-switch 2D/3D
    function _handleGSA(fields) {
      _last_pos_data.mode1 <- fields[1];
      // "1" = Fix not available
      // "2" = 2D (<4 SVs used)
      // "3" = 3D (>= 4 SVs used)
      _last_pos_data.mode2 <- fields[2];
      // Satellites Used on Channel 1
      _last_pos_data.sats_used_1 <- fields[3] != "" ? fields[3].tointeger() : 0;
      _last_pos_data.sats_used_2 <- fields[4] != "" ? fields[4].tointeger() : 0;
      _last_pos_data.sats_used_3 <- fields[5] != "" ? fields[5].tointeger() : 0;
      _last_pos_data.sats_used_4 <- fields[6] != "" ? fields[6].tointeger() : 0;
      _last_pos_data.sats_used_5 <- fields[7] != "" ? fields[7].tointeger() : 0;
      _last_pos_data.sats_used_6 <- fields[8] != "" ? fields[8].tointeger() : 0;
      _last_pos_data.sats_used_7 <- fields[9] != "" ? fields[9].tointeger() : 0;
      _last_pos_data.sats_used_8 <- fields[10] != "" ? fields[10].tointeger() : 0;
      _last_pos_data.sats_used_9 <- fields[11] != "" ? fields[11].tointeger() : 0;
      _last_pos_data.sats_used_10 <- fields[12] != "" ? fields[12].tointeger() : 0;
      _last_pos_data.sats_used_11 <- fields[13] != "" ? fields[13].tointeger() : 0;
      _last_pos_data.sats_used_12 <- fields[14] != "" ? fields[14].tointeger() : 0;
      // Positional Dilution of Precision
      _last_pos_data.pdop <- fields[15].tofloat();
      // Horizontal Dilution of Precision
      _last_pos_data.hdop <- fields[16].tofloat();
      // Vertical Dilution of Precision
      _last_pos_data.vdop <- fields[17].tofloat();
  
      if (_dop_update_cb) _dop_update_cb(_last_pos_data);      
    }
    
    // -------------------------------------------------------------------------
    // Handle GxGSV Packet: GNSS Satellites in View
    // Ex: "$GPGSV,3,1,09,29,36,029,42,21,46,314,43,26,44,020,43,15,21,321,39*7D"
    // Number of Messages (3)
    function _handleGSV(fields) {
      local num_messages = fields[1].tointeger();
      local message_number = fields[2].tointeger();
      _last_pos_data.sats_in_view <- fields[3].tointeger();
      if ("sats" in _last_pos_data) {
        // hi
      } else {
        _last_pos_data.sats <- [];
      }
      local i = 4; // current index in fields
      while (i < (fields.len() - 4)) {
          local sat = {};
          sat.id <- fields[i] != "" ? fields[i].tointeger() : null;
          sat.elevation <- fields[++i] != "" ? fields[i].tofloat() : null;
          sat.azimuth <- fields[++i] != "" ? fields[i].tofloat() : null;
          sat.snr <- fields[++i] != "" ? fields[i].tofloat() : null;
          _last_pos_data.sats.push(sat);
      }
  
      if (_sats_update_cb) _sats_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    // Handle GxRMC Packet: Minimum Recommended Navigation Information
    // Ex: "$GPRMC,064951.000,A,2307.1256,N,12016.4438,E,0.03,165.48,260406,3.05,W,A*2C "
    // UTC time hhmmss.sss
    function _handleRMC(fields) {
      _last_pos_data.time <- _parseUTC(fields[1]);
      // Status A=Valid V=Not Valid
      _last_pos_data.status <- fields[2];
      // ddmm.mmmm
      _last_pos_data.lat <- _parseCoordinate(fields[3]);
      // N/S Indicator
      _last_pos_data.ns <- fields[4];
      if (_last_pos_data.ns == "S") {
        _last_pos_data.lat = -1 * _last_pos_data.lat;
      }
      // ddmm.mmmm
      _last_pos_data.lon <- _parseCoordinate(fields[5]);
      // E/W Indicator
      _last_pos_data.ew <- fields[6];
        if (_last_pos_data.ew == "W") {
        _last_pos_data.lon = -1 * _last_pos_data.lon;
      }
      // Ground speed in knots
      _last_pos_data.gs_knots <- fields[7].tofloat();
      // Course over Ground, Degrees True
      _last_pos_data.true_course <- fields[8].tofloat();
      // Date, ddmmyy
      _last_pos_data.date <- fields[9];
      // Magnetic Variation (Not available)
      _last_pos_data.mag_var <- fields[10];
      // Mode (A = Autonomous, D = Differential, E = Estimated)
      _last_pos_data.mode <- fields[11];
      
      if (_rmc_update_cb) _rmc_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    // Handle GxVTG Packet: Course and Speed information relative to ground
    // Ex: "$GPVTG,165.48,T,,M,0.03,N,0.06,K,A*37 "
    // Measured Heading, Degrees
    function _handleVTG(fields) {
      _last_pos_data.true_course <- fields[1].tofloat();
      // Course Reference (T = True, M = Magnetic)
      _last_pos_data.course_ref <- fields[2];
      // _last_pos_data.course_2 <- fields[3];
      // _last_pos_data.ref_2 <- fields[4];
      // Ground Speed in Knots
      _last_pos_data.gs_knots <- fields[5].tofloat();
      // Ground Speed Units, N = Knots
      //_last_pos_data.gs_units_1 <- fields[6];
      // Ground Speed in km/hr
      _last_pos_data.gs_kmph <- fields[7].tofloat();
      // Ground Speed Units, K = Km/Hr
      //_last_pos_data.gs_units_2 <- fields[8];
      // Mode (A = Autonomous, D = Differential, E = Estimated)
      _last_pos_data.mode <- fields[9];
  
      if (_vtg_update_cb) _vtg_update_cb(_last_pos_data);
    }

    // -------------------------------------------------------------------------
    // Handle PGTOP Packet: Antenna Status Information
    // Ex: "$PGTOP,11,3 *6F"
    // Function Type (??)
    //_last_pos_data.function_type <- fields[1];
    // Antenna Status
    // 1 = Active Antenna Shorted
    // 2 = Using Internal Antenna
    // 3 = Using Active Antenna
    function _handlePGTOP(fields) {
      _last_pos_data.ant_status <- fields[2].tointeger();
    
      if (_ant_status_update_cb) _ant_status_update_cb(_last_pos_data);
    }
    
    // -------------------------------------------------------------------------
    function wakeup() {
        _uart.write(" ");
    }
    
    // -------------------------------------------------------------------------
    function standby() {
       _sendCmd(PMTK_STANDBY);
    }
     
    // -------------------------------------------------------------------------
    
    function setBaud(baud) {
        if (baud == _uart_baud) return;
        if ((baud != 9600) && (baud != 57600)) throw format("Unsupported baud (%d); supported rates are 9600 and 57600",baud);
        if (baud == 57600) _sendCmd(PMTK_SET_BAUD_57600);
        else _sendCmd(PMTK_SET_BAUD_9600);
        _uart_baud = baud;
        _uart.configure(_uart_baud, 8, PARITY_NONE, 1, NO_CTSRTS, _uartCallback.bindenv(this));
    }
    
    // -------------------------------------------------------------------------
    function setPositionCallback(cb) {
        _position_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    function setDopCallback(cb) {
        _dop_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    function setSatsCallback(cb) {
        _sats_update_cb = cb;
    }    

    // -------------------------------------------------------------------------
    function setRmcCallback(cb) {
        _rmc_update_cb = cb;
    }

    // -------------------------------------------------------------------------
    function setVtgCallback(cb) {
        _vtg_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    function setAntStatusCallback(cb) {
        _ant_status_update_cb = cb;
    }
    
    // -------------------------------------------------------------------------
    // Controls how frequently the GPS tells us the latest position solution
    // This does not control the rate at which solutions are generated; use setUpdateRate to change that
    // Max Rate 10 Hz (0.1s per report)
    // Min Rate 100 mHz (10s per report)
    // Input: rateSeconds - the time between position reports from the GPS
    // Return: None
    function setReportingRate(rateSeconds) {
        if (rateSeconds <= 0.1) {
            _sendCmd(PMTK_SET_NMEA_UPDATE_10HZ);
        } else if (rateSeconds <= 0.5) {
            _sendCmd(PMTK_SET_NMEA_UPDATE_5HZ);
        } else if (rateSeconds <= 1) {
            _sendCmd(PMTK_SET_NMEA_UPDATE_1HZ);
        } else {
            _sendCmd(PMTK_SET_NMEA_UPDATE_100_MILLIHERTZ);
        }
    }
    
    // -------------------------------------------------------------------------
    // Controls how frequently the GPS calculates a position solution
    // Max rate 5Hz (0.2s per solution)
    // Min rate 100 mHz (10s per solution)
    // Input: rateSeconds - time between solutions by the GPS
    // Return: None
    function setUpdateRate(rateSeconds) {
        if (rateSeconds <= 0.2) {
            _sendCmd(PMTK_API_SET_FIX_CTL_5HZ);
        } else if (rateSeconds <= 1) {
            _sendCmd(PMTK_API_SET_FIX_CTL_1HZ);
        } else {
            _sendCmd(PMTK_API_SET_FIX_CTL_100_MILLIHERTZ);
        } 
    }
    
    // -------------------------------------------------------------------------
    // Set mode to RMC (rec minimum) and GGA (fix) data, incl altitude
    function setModeRMCGGA() {
        _sendCmd(PMTK_SET_NMEA_OUTPUT_RMCGGA);
    }
    
    // -------------------------------------------------------------------------
    // Set mode to RMC (rec minimum) ONLY: best for high update rates
    function setModeRMC() {
        _sendCmd(PMTK_SET_NMEA_OUTPUT_RMCONLY);
    }
    
    // -------------------------------------------------------------------------
    // Set mode to ALL. This will produce a lot of output...
    function setModeAll() {
        _sendCmd(PMTK_SET_NMEA_OUTPUT_ALLDATA);
    }
    
    // -------------------------------------------------------------------------
    function getPosition() {
        return _last_pos_data;    
    }
}

// Consts and Globals ----------------------------------------------------------

const RATE_HZ = 1.0;
const SPICLK = 4000; // kHz
const STEPS_PER_REV = 20; 
const DECLINATION = 13.5; // degrees, Oakland, CA
//const DECLINATION = 0;

dest <- {
  lat = 39.2904,
  lon = -76.6122
}

// Setup -----------------------------------------------------------------------

// TODO: Fix memory leak in GPS
// TODO: increase GPS Baud
// TODO: Add Hall sensor to detect home position on wake
// TODO: Add offline operation
// TODO: Add Wake source

// TODO: Fix parsing error before fix (	the index '0' does not exist (line 633), Pkt: GNGGA,200313.000,,,,,0,0,,,M,,M,,*55
// 2017-10-07 13:03:13 -07:00	[Device]	cannot convert the string (line 671), Pkt: GPGSA,A,1,,,,,,,,,,,,,,,*1E
// 2017-10-07 13:03:13 -07:00	[Device]	cannot convert the string (line 671), Pkt: GLGSA,A,1,,,,,,,,,,,,,,,*02
// 2017-10-07 13:03:13 -07:00	[Device]	the index '0' does not exist (line 633), Pkt: GNRMC,200313.000,V,,,,,1.40,355.73,071017,,,N*52)

imp.enableblinkup(true);

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

uart <- hardware.uart6E;
uart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);
// Todo: figure out how to up the baud rate on this thing

spi <- hardware.spi257;
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, 234);
cs_l <- hardware.pinA;
cs_l.configure(DIGITAL_OUT);
cs_l.write(1);
motor_stby <- hardware.pinD;
motor_stby.configure(DIGITAL_OUT);
motor_stby.write(0);

imu <- LSM9DS0(i2c);
gps <- MT333X(uart);
motor <- L6470(spi, cs_l, motor_stby);

// Enable the Magnetometer by setting the ODR to a non-zero value
imu.setDatarate_M(1); // 1 Hz - nearest supported rate is 3.125 Hz 
imu.setModeCont_M(); // enable continuous measurement

gps.setUpdateRate(1);
gps.setReportingRate(1);

// 1/64 step microstepping
motor.setStepMode(STEP_SEL_1_64);
motor.setMaxSpeed(10 * STEPS_PER_REV); 
server.log(format("Max speed set to %d steps/s", motor.getMaxSpeed()));
motor.setFSSpeed(10 * STEPS_PER_REV);
server.log(format("Full-stepping speed set to %d steps/s", motor.getFSSpeed()));
motor.setAcc(0x0fff); // max
motor.setOcTh(500); // mA
motor.setConfig(CONFIG_INT_OSC | CONFIG_PWMMULT_2_000);

// limit applied voltage while running to 1V
// 1 / 9 = 0.11
motor.setRunKval(0.11); 

// motor is rated for ~6V, but driving it hard during accel browns out our crappy power supply
// seems to start and run just fine at 1V
// 6 / 9 = 0.67
// this should prevent us from stalling.
motor.setAccKval(0.11);
motor.setDecKval(0.11);

// limit the applied voltage in hold state to 0.5V. (0.5 / 9 = 0.05) 
// if we don't even need this, we should keep turning it down. It just wastes power.
motor.setHoldKval(0.05);

// enable low-speed position optimization
//motor.setLspdPosOpt(1);
//server.log("Motor LSPD_OPT Bit: "+motor.getLspdPosOpt());

server.log(format("Status Register: 0x%04x", motor.getStatus()));
server.log(format("Config Register: 0x%04x", motor.getConfig()));

// Helpers ---------------------------------------------------------------------

function degToRad(deg) {
  return deg * (PI / 180.0);
}

function radToDeg(rad) {
  return rad * (180.0 / PI);
}

function getAttitude() {

    local accel = imu.getAccel();
    local result = {};
    
    result.roll <- math.atan2(accel.y , accel.z);
    result.pitch <- math.atan(-1.0 * accel.x, (accel.y * math.sin(result.roll) + accel.z * math.sin(result.roll)));

    return result;
}

function getHdg() {
  local mag_raw = imu.getMag();
  local hdg = 180.0 * math.atan2(mag_raw.y, mag_raw.x) / PI;

  if (hdg < 0) {
      hdg += 360;
  }

  return hdg;
}

function getBearingTo(pos, fix) {
  local pos_lon = degToRad(pos.lon);
  local pos_lat = degToRad(pos.lat);
  local fix_lon = degToRad(fix.lon);
  local fix_lat = degToRad(fix.lat);
  
  local y = math.sin(fix_lon - pos_lon) * math.cos(fix_lat);
  local x = math.cos(pos_lat) * math.sin(fix_lat) - math.sin(pos_lat) * math.cos(fix_lat) * math.cos(fix_lon - pos_lon);
  local bearing = radToDeg(math.atan2(y, x)); // return degrees true

  if (bearing < 0) {
    bearing += 360;
  }
  
  return bearing;
}

function datapoint() {
  
  // Now read everything
  server.log(format("Hdg: %0.2fº Mag", getHdg() + DECLINATION));
  local pos = gps.getPosition();
  local bearing = 180;
  if ("lat" in pos && "lon" in pos) {
    bearing = getBearingTo(pos, dest);
    server.log(format("Bearing to (%0.6f, %0.6f): %0.2fº True", dest.lat, dest.lon, bearing));
    server.log(format("Position at %sZ: %0.6f, %0.6f", pos.time, pos.lat, pos.lon));
  } else {
    server.log("GPS waiting for fix");
  }
  server.log(format("Motor Status: 0x%04X", motor.getStatus()));
  
  // Point where we want to go
  if (!motor.isBusy()) {
    motor.goTo( (STEPS_PER_REV / 360.0) * bearing );
  }
  
  imp.wakeup(1.0/RATE_HZ, datapoint);
}

// Go --------------------------------------------------------------------------

datapoint();

// test the motor
server.log("Attempting to find home position");
motor.goUntil(1, 20);