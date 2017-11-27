# Magic Compass

This project uses an Electric imp, a GPS, a magnetometer, and a small stepper motor to show the course from its current position to a pre-programmed set of coordinates.

## Parts

1. [imp002 EVB](https://electricimp.com/docs/hardware/imp002evb/)
    * These are not commercially available, but the schematics are attached. 
1. You'll need a 9V rail in the box. You can take the route I took (see Modifications section), or just get a 9V boost module like [this one from Pololu](https://www.pololu.com/product/2116).
1. [L6470 Stepper Motor Driver Breakout](https://www.sparkfun.com/products/retired/10859)
    * Sparkfun retired these, but I got one on eBay. The IC was flaky and I ordered another from Digikey and replaced it.
1. ["Qwiic GPS" Breakout, aka Titan X1, aka MT3339](https://www.sparkfun.com/products/14414)
    * Picked this for I2C interface, haven't gotten around to implementing it. Using UART for now. 
1. Electric Imp 9DOF Tail.
    * Also not commercially available, but it's just an ST LSM9DS0 breakout.
        * [Adafruit sells one.](https://www.adafruit.com/product/2021)
            * Since we're only using the magnetometer, an [LIS3MDL magnetometer](http://www.st.com/content/ccc/resource/technical/document/datasheet/54/2a/85/76/e3/97/42/18/DM00075867.pdf/files/DM00075867.pdf/jcr:content/translations/en.DM00075867.pdf) would likely do just fine with minimal code changes. Finding a breakout is an exercise for the reader, and there's plenty of excuse here already for a custom PCB.
1. LiPo battery. I'm using a [2Ah one from Sparkfun](https://www.sparkfun.com/products/13855) because I have no subtlety. 
    * You could definitely make this smaller, probably by an order of magnitude or two. 
1. Tiny cheapo 4-wire stepper motor. 
    * [I got 10 from Amazon for $10.](https://www.amazon.com/gp/product/B00A9SU77E/ref=oh_aui_detailpage_o00_s00?ie=UTF8&psc=1). That "product" is discontinued but there are hundreds of other similar listings and you can try your luck with any of those without too much risk. 
        * Changing the motor will change the mounting hardware. I'm pretty sure the output shaft on mine is an M1.7x0.35 thread, and the mounting screws appear to be M1.2x0.25. I bought these parts from some backwater website and we'll see if they ever show up. If they don't I'll glue stuff together. 
1. Hall switch. I used an [AH3366Q](https://www.digikey.com/product-detail/en/diodes-incorporated/AH3366Q-P-B/AH3366Q-P-BDI-ND/6575186). A bipolar sensor would have been easier (don't have to get the magnet the right way around).
1. Tiny magnet to sense needle position with Hall switch - I got a [ridiculous number of 2mm x 1mm magnets on Amazon for $10](https://www.amazon.com/Stainless-Magnets-Refrigerator-Projects-Whiteboard/dp/B072KRP66C/ref=sr_1_1?ie=UTF8&qid=1511743885&sr=8-1&keywords=magnet+1mm). There are lots of options here. 
1. Limit switch for sensing lid open/closed: [HDP001R from C&K](https://www.digikey.com/product-detail/en/c-k/HDP001R/CKN10548CT-ND/5030194)
1. Enclosure
    * Lid and base were cut from a sheet of 1/8" maple with a Glowforge. Used Glowforge proof-grade. 
    * You can order the parts cut from [Ponoko](https://www.ponoko.com/). 
1. Rear hinges are [Ace Hardware 5299706 3/4" Brass hinges](http://acehardwaremaldives.com/product/hardware/5299706/#.WhuBTbQ-fUI).
1. Front latch is an [Ace Hardware 5300199 1 5/16" Decorative Catch](http://www.acehardware.com/product/index.jsp?productId=29262156). 

## Modifications to Parts

1. The L6470 requires 8V or greater to operate. It won't even talk back over SPI if you apply less. 
    * The imp002 EVB has a boost on it, but it's a 5V boost. Changing the feedback network to greater than 6V will cause the part to fail (tried this).
    * I removed the imp002 EVB boost (a TPS61070), and replaced it with a [TPS61040 LED boost controller](https://www.digikey.com/product-detail/en/texas-instruments/TPS61040QDBVRQ1/296-23425-1-ND/1851362). 
        * This required the Feedback and enable traces coming into the footprint to be cut and swapped on the footprint. 
        * An external schottky diode must also be installed from pin 1 to the output. 
1. I disabled powersave mode on the TPS63031 buck/boost on the imp002 EVB. This feature causes the supply to stop switching when load is under ~100mA and bus voltage is within a few hundred millivolts of 3.3V, which is basically normal operation for this device all the time. This causes absurd ripple on the 3.3V rail, which makes the output cap sing like a canary even when the device is asleep, which is unacceptable. 
    * Cut the trace going into Pin 7 of the TPS63031 (U12), and short pins 6 and 7 together on the TPS63031. 
1. You probably want to disconnect Button 1 from Pin1 on the imp002 EVB; it's got a 100kΩ pulldown on it and might mess with the operation of the wake switch. I didn't risk it; I pulled D50 off the board. 
    * After doing this, a 4.7kΩ pullup from imp Pin1 to 3V3 is required. The limit switch holds the line low when the lid is shut, letting the imp sleep. 

## Integration

1. Modify the imp002 EVB as necessary. 
1. It's a good idea to harness the whole thing together before you put it in the box. A 2" pigtail between each board should be plenty to allow you to fold everything into place in the box. 
    1. Connect imp pins per the pinout below.
    1. Connect your 9V+ output to V+ on the L6470 breakout. If you modified the imp002 EVB's boost converter, this rail is the new "5V0" rail. Probably note this on the board if you don't want to buy more parts.
    1. Connect 3V3 on the imp002 EVB to 3V3 on the GPS board and 9DOF tail. Also connect 3V3 to the "5V" pad on the L6470; this is the I/O / Logic supply, and it's perfectly happy at 3.3V. 
    1. Connect ground on everything. 
    1. Attach wires to the leads on the hall sensor and run them through the sub-top piece of the enclosure before attaching them. You can connect 3V3 and GND pretty much wherever, the output line goes to the "SW" input on the bottom edge of the L6470 breakout.
  ![Pinout](/images/AH3366Q_pinout.PNG)
    1. Attach wires to the bottom leads on the limit switch (polarity is not important). One end goes to GND (anywhere), other end goes to Pin1 on the imp.
    1. Wire motor to L6470 breakout as shown in the pinout below. I recommend bringing the phase wires out the bottom of the L6470 breakout as it is mounted upside-down as close to the right wall as possible.
1. Assemble enclosure. 
    1. Build the bottom and four walls together, then stop. 
    ![Enclosure Assembly](/images/encl-assy0.JPG)
    1. The little 1cm x 1cm squares are shelves. Fit them into the rear and right walls of the enclosure like so:
    ![Shelves](/images/encl-shelves.JPG)
1. Build into enclosure.
    1. Apply foam tape to the battery, bottom of the imp002 EVB, bottom of the 9DOF tail, and bottom of the GPS module.
    1. Stick the battery down in the rear-left corner of the case. 
    ![Assembly Step 1](/images/encl-assy1.JPG)
    1. Stick the imp down on top of the battery, in the rear-left corner of the case, so the USB connector and on/off switch line up with the holes in the enclosure. 
    1. Stick the 9DOF tail down in the front-left corner of the case. 
    1. Stick the GPS down next to the 9DOF tail. 
    ![Assembly Step 2](/images/encl-assy2.JPG)
    1. Apply foam tape to the shelves.
    1. Flip the L6470 driver upside down and stick it down on the shelves. 
    ![Assembly Step 3](/images/encl-assy3.JPG)
    1. Fit the motor through the hole in the center of the sub-top. Use 2x M1.2x0.25 screws fit through the top of the sub-top piece to secure the motor to the top. Or maybe they don't fit and just glue it there. Good luck. 
    1. Glue the hall sensor down to the left side of the motor on the sub-top piece. 
    1. Drop the sub-top piece into the enclosure. If you have to glue it do so with something you can remove later so you can work on the guts if you have to. 
    ![Assembly Step 4](/images/encl-assy4.JPG)
1. Make a compass needle out of cardstock. 
1. Install the compass needle.
    1. Attach a magnet to the bottom of the compass needle so it'll pass directly over the hall sensor. Make sure you get the magnet the right way around if you didn't switch to a bipolar hall sensor. 
    1. Attach the needle to the motor shaft. I'm usng 2x M1.7 nuts and maybe some glue. Make sure to position the needle so that the the motor isn't resting at one of its natural detents when the magnet is right over the hall sensor - there's a bug in either the L6470 or in my firmware that will cause the needle to get stuck if the compass wakes up with the motor already at the home position. 
    ![Assembly Step 5](/images/magnet.JPG)
1. Drop the top piece on over the compass needle. Should look nice. 
    ![Assembly Step 6](/images/encl-base-done.JPG)
1. Build the lid. 
1. Install the hinges. 
1. Install the clasp.
1. BlinkUp the imp, load the firmware. If you don't know what I'm talking about go read the [getting started guide](https://electricimp.com/docs/gettingstarted/). 
1. Have a beer.

### Pinout

#### Imp 002 EVB

| Imp Pin | Configured As | Connect To |
| ------- | ------------- | ---------- |
| Pin1 | DIGITAL_IN when awake, DIGITAL_IN_WAKEUP when asleep | 10kΩ pullup, limit switch (other side to ground) |
| Pin2 | SPI MISO / DIGITAL_OUT - VBAT sense enable | L6470 DO |
| Pin5 | SPI SCLK | L6470 CK |
| Pin6 | UART TX | GPS RX |
| Pin7 | SPI MOSI | L6470 DI |
| Pin8 | I2C SCL | 9DOF Tail SCL (Marked "Pin8") |
| Pin9 | I2C SDA | 9DOF Tail SDA (Marked "Pin9") |
| PinA | SPI CS_L (DIGITAL_OUT) | L6470 CS |
| PinB | ANALOG_IN - VBAT sense | None (Connected on imp002 EVB) |
| PinC | DIGITAL_OUT | L6470 STBY |
| PinD | Not Used (Button 1 on imp002 EVB) | None |
| PinE | UART RX | GPS TX |

![Pinout](/images/prototype-pinout.JPG)

#### Motor

This pinout produces clockwise rotation in the "forward" direction. Motor pins are listed as if you are looking at the pins head-on. 

| Motor Pin | L6470 Pin |
| --------- | --------- |
| Top-Left | O1B |
| Top-Right | O1A |
| Bottom-Left | O2B |
| Bottom-Right | O2A |

![Motor Phases](/images/phases-motor.JPG)
![L6470](/images/phases-driver.JPG)

## Enclosure

Outline and most square and rectangular holes were designed with [Makercase](http://www.makercase.com/?laserKerfInput=0.2), which is sorta buggy and not great, but still saved me a bunch of time. Makercase export .json files are in the enclosure folder. I edited by hand to remove the bottom of the lid, and add the sub-top piece that supports the motor and compass needle. I used Inkscape for all of this and it only sucked a little bit. SVG files are in the enclosure folder. 

I recommend *not* glueing the sub-top and top pieces into the base of the compass, as it will make working on the device later impossible. 

### Base 

#### Front
![Base Front](/images/encl-front.JPG)
#### Right
![Base Right](/images/encl-right.JPG)
#### Back
![Base Back](/images/encl-back.JPG)
#### Left
![Base Left](/images/encl-left.JPG)

### Lid

#### Front
![Lid Front](/images/lid-front.JPG)
#### Right
![Lid Right](/images/lid-right.JPG)
#### Back
![Lid Back](/images/lid-back.JPG)
#### Left
![Lid Left](/images/lid-left.JPG)

## Firmware

The firmware currently uses the LSM9DS0 library from Electric Imp. Imp has libraries for the L6470 and for the MT333X family of GPS parts, but too many modifications were needed to use these right out of the box. I will upstream my changes and hope to switch the the "requireable" versions of these libraries later. For now, just copy/paste into the IDE.

## Known Issues / Future Improvements

1. The compass becomes unresponsive to sleep/wake events, and sometimes also fails to move the stepper motor, when the GPS acquires lock.
    * This may be due to a storm of UART callback events when the GPS determines its position. Switching the GPS to I2C would solve this without sorting out a bunch of additional commands for the MT3339. This would also eliminate the UART wiring by putting the GPS and Magnetometer on the same I2C bus.
1. Hacked-together power supply has very high output impedance and low current limit.
    * Increasing the motor K values very much causes undervoltage lockout conditions sometimes when the motor is commanded to move. Using a proper boost would resolve this. 
    * I did order a few [Pololu 9V step-up modules](https://www.pololu.com/product/2116) with the intent of using one, but my hackjob power supply is holding up well enough I haven't done this yet. 
1. Enclosure SVGs do not currently include laser kerf correction, which can easily be applied in Makercase. The enclosure prints and assembles nicely, but requires glue to stay together.
    * A 0.002" (0.0508 mm) kerf correction should produce a holds-itself-together press fit. 
    * A 0.0025" (0.0635 mm) kerf correction should produce a hard-to-press-together-and-maybe-doesn't-need-glue fit. 
1. The 4.7kΩ pullup on Pin1 grounded through the limit switch wastes almost 1mA when the imp is asleep; the imp sleeps at < 10µA, so this is pretty eggregious. With a 2 Ah battery, this is still ~90 days of sleep standby time, so whatever, but if I make a custom board I'll fix the wake logic so it actually saves power. 