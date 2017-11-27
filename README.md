# Magic Compass

This project uses an Electric imp, a GPS, a magnetometer, and a small stepper motor to show the course from its current position to a pre-programmed set of coordinates.

## Parts

* [imp002 EVB](https://electricimp.com/docs/hardware/imp002evb/)
** These are not commercially available, but the schematics are attached. 
* You'll need a 9V rail in the box. You can take the route I took (see Modifications section), or just get a 9V boost module like [this one from Pololu](https://www.pololu.com/product/2116).
* [L6470 Stepper Motor Driver Breakout](https://www.sparkfun.com/products/retired/10859)
** Sparkfun retired these, but I got one on eBay. The IC was flaky and I ordered another from Digikey and replaced it.
* ["Qwiic GPS" Breakout, aka Titan X1, aka MT3339](https://www.sparkfun.com/products/14414)
** Picked this for I2C interface, haven't gotten around to implementing it. Using UART for now. 
* Electric Imp 9DOF Tail.
** Also not commercially available, but it's just an ST LSM9DS0 breakout.
*** [Adafruit sells one.](https://www.adafruit.com/product/2021)
**** Since we're only using the magnetometer, an [LIS3MDL magnetometer](http://www.st.com/content/ccc/resource/technical/document/datasheet/54/2a/85/76/e3/97/42/18/DM00075867.pdf/files/DM00075867.pdf/jcr:content/translations/en.DM00075867.pdf) would likely do just fine with minimal code changes. Finding a breakout is an exercise for the reader, and there's plenty of excuse here already for a custom PCB.
* LiPo battery. I'm using a [2Ah one from Sparkfun](https://www.sparkfun.com/products/13855) because I have no subtlety. 
** You could definitely make this smaller, probably by an order of magnitude or two. 
* Tiny cheapo 4-wire stepper motor. 
** [I got 10 from Amazon for $10.](https://www.amazon.com/gp/product/B00A9SU77E/ref=oh_aui_detailpage_o00_s00?ie=UTF8&psc=1). That "product" is discontinued but there are hundreds of other similar listings and you can try your luck with any of those without too much risk. 
*** Changing the motor will change the mounting hardware. I'm pretty sure the output shaft on mine is an M1.7x0.35 thread, and the mounting screws appear to be M1.2x0.25. I bought these parts from some backwater website and we'll see if they ever show up. If they don't I'll glue stuff together. 
* Hall switch. I used an [AH3366Q](https://www.digikey.com/product-detail/en/diodes-incorporated/AH3366Q-P-B/AH3366Q-P-BDI-ND/6575186). A bipolar sensor would have been easier (don't have to get the magnet the right way around).
* Tiny magnet to sense needle position with Hall switch - I got a [ridiculous number of 2mm x 1mm magnets on Amazon for $10](https://www.amazon.com/Stainless-Magnets-Refrigerator-Projects-Whiteboard/dp/B072KRP66C/ref=sr_1_1?ie=UTF8&qid=1511743885&sr=8-1&keywords=magnet+1mm). There are lots of options here. 
* Limit switch for sensing lid open/closed: [HDP001R from C&K](https://www.digikey.com/product-detail/en/c-k/HDP001R/CKN10548CT-ND/5030194)
* Enclosure
** Lid and base were cut from a sheet of 1/8" maple with a Glowforge. Used Glowforge proof-grade. 
** You can order the parts cut from [Ponoko](https://www.ponoko.com/). 

## Modifications to Parts

* The L6470 requires 8V or greater to operate. It won't even talk back over SPI if you apply less. 
** The imp002 EVB has a boost on it, but it's a 5V boost. Changing the feedback network to greater than 6V will cause the part to fail (tried this).
** I removed the imp002 EVB boost (a TPS61070), and replaced it with a [TPS61040 LED boost controller](https://www.digikey.com/product-detail/en/texas-instruments/TPS61040QDBVRQ1/296-23425-1-ND/1851362). 
*** This required the Feedback and enable traces coming into the footprint to be cut and swapped on the footprint. 
*** An external schottky diode must also be installed from pin 1 to the output. 
* I disabled powersave mode on the TPS63031 buck/boost on the imp002 EVB. This feature causes the supply to stop switching when load is under ~100mA and bus voltage is within a few hundred millivolts of 3.3V, which is basically normal operation for this device all the time. This causes absurd ripple on the 3.3V rail, which makes the output cap sing like a canary even when the device is asleep, which is unacceptable. 
** Cut the trace going into Pin 7 of the TPS63031 (U12), and short pins 6 and 7 together on the TPS63031. 
* Some modification will be needed to the wake system on the EVB to install the lid switch. TBA.

## Integration

### Pinout

| Imp Pin | Configured As | Connect To |
| ------- | ------------- | ---------- |


## Enclosure

Outline and most square and rectangular holes were designed with [Makercase](http://www.makercase.com/?laserKerfInput=0.2), which is sorta buggy and not great, but still saved me a bunch of time. Makercase export .json files are in the enclosure folder. I edited by hand to remove the bottom of the lid, and add the sub-top piece that supports the motor and compass needle. I used Inkscape for all of this and it only sucked a little bit. SVG files are in the enclosure folder. 

I recommend *not* glueing the sub-top and top pieces into the base of the compass, as it will make working on the device later impossible. 

## Firmware

The firmware currently uses the LSM9DS0 library from Electric Imp. Imp has libraries for the L6470 and for the MT333X family of GPS parts, but too many modifications were needed to use these right out of the box. I will upstream my changes and hope to switch the the "requireable" versions of these libraries later. For now, just copy/paste into the IDE.

## Known Issues / Future Improvements

* The compass becomes unresponsive to sleep/wake events, and sometimes also fails to move the stepper motor, when the GPS acquires lock.
** This may be due to a storm of UART callback events when the GPS determines its position. Switching the GPS to I2C would solve this without sorting out a bunch of additional commands for the MT3339. This would also eliminate the UART wiring by putting the GPS and Magnetometer on the same I2C bus.
* Hacked-together power supply has very high output impedance and low current limit.
** Increasing the motor K values very much causes undervoltage lockout conditions sometimes when the motor is commanded to move. Using a proper boost would resolve this. 
** I did order a few [Pololu 9V step-up modules](https://www.pololu.com/product/2116) with the intent of using one, but my hackjob power supply is holding up well enough I haven't done this yet. 
