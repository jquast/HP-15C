/**
 * File: MnemonicConverter.js
 *
 * Version: 0.93.000
 *
 * Author: Nina Scholz (nina[at]the-abc.de)
 * Date: 2012-04-14
 * Updates:
 *   2013-05-22 Torsten Manz
 *     Added Unicode characters '÷', '×', '↓', '↑', '→', '↔', '∑', 'ŷ', '≥', '≤'
 *     Replaced 'Sigma' by '∑' in key code display
 *     Fixed duplicate code 43 for 'RND'
 *   2019-01-25 Torsten Manz
 *     Fixed wrong key code for STO/RCL A-C in USER mode
 *   2021-03-15 Torsten Manz
 *     Allowed 'Latin Letter Small Capital E' (U+1D07) as exponent char in input
 *   2022-03-28 Torsten Manz
 *     Added mnemonics 'ENTER↑', 'R^, 'X≠0', 'X≠0?', 'X≠Y', 'X≠Y?' (and vice versa)
 *   2022-04-24 Torsten Manz
 *     Error format using CSS. Requires <div> element as output.
 *   2023-07-27 Torsten Manz
 *     Added mnemonics 'Σ+' and 'Σ-'
 *   2027-02-11 Torsten Manz
 *     Added mnemonics using arrow '⇔' (u21D4) instead of '↔' (u2194)
 *     Added mnemonics '√X', 'Π'
 *     Replaced '*' with ×', "/" with '÷' in key codes output
 *
 * Summary of File:
 *
 * Converts given Mnemonics for the HP 15C to keycode, needed for the HP 15c
 * simulator at https://HP-15C-Simulator.de
 *
 * Constructor:
 *
 * HP15cNamesSpace.MnemonicToKeycode()
 *
 * Public Methods:
 *
 * getSimulator()
 * setSimulator(s) 
 *		s: switch between key 48 (https://HP-15C-Simulator.de simulator style) and .1 (other/unknown)
 *
 * getPrefixKey()
 * setPrefixKey(p)
 *		p: toggles the display of the prefix keys f and g
 *
 * getOMPL()
 * setOMPL(ompl)
 *		ompl: toggles the interpretation of the given mnmonics. acronym for one mnemonic per line
 *
 * getHP15cCommand()
 *
 * convert(m)
 *		m: converts mnemonics to key codes and mnemonic
 *
 * Sample:
 *
 * var o = new HP15cNamesSpace.MnemonicToKeycode();
 * o.convert(this.mnemonics.value);
 **/

String.prototype.trim = function () { return this.replace(/^\s+|\s+$/g, ''); };
String.prototype.ltrim = function () { return this.replace(/^\s+/, ''); };
String.prototype.rtrim = function () { return this.replace(/\s+$/, ''); };
String.prototype.entityfy = function () { return this.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); };

String.prototype.format = function () {
	var a;
	if (arguments[0] && typeof arguments[0] === 'object') {
		a = arguments[0];
	} else {
		a = arguments;
	}
	a['{'] = '{';
	a['}'] = '}';
	return this.replace(
		/{({|}|-?[0-9]+)}/g,
		function (item) {
			var result = a[item.substring(1, item.length - 1)];
			return typeof result === 'undefined' ? '' : result;
		}
	);
};

var HP15cNamesSpace = {};

HP15cNamesSpace.MnemonicToKeycode = function () {

	var	i, j,
		bSimulator,
		bPrefixKey,
		bOMPL,							// one mnemonic per line
		sIdentifier,
//		sComment,
		oLetter,
		oRecombine,
		oFirstPassMnemonic,
		oHP15cCommandPrefix,
		oHP15cCommandPartLabel,
		oHP15cCommandPartRegister,
		oHP15cCommandPartRegisterArithmetic,
		oHP15cCommandPartTrigonometry,
		oHP15cCommand;

	bSimulator = true;
	bPrefixKey = true;
	bOMPL = true;

	this.getSimulator = function () { return bSimulator; };
	this.setSimulator = function (s) { bSimulator = s; };
	this.getPrefixKey = function () { return bPrefixKey; };
	this.setPrefixKey = function (p) { bPrefixKey = p; };
	this.getOMPL = function () { return bOMPL; };
	this.setOMPL = function (ompl) { bOMPL = ompl; };
	this.getHP15cCommand = function () { return JSON.stringify(oHP15cCommand, null, '\t').entityfy(); };
	this.getFirstPassMnemonic = function () { return JSON.stringify(oFirstPassMnemonic, null, '\t').entityfy(); };

	oRecombine = {
		'X!=0?': 'TEST 0',
		'X!=0': 'TEST 0',
		'X≠0': 'TEST 0',
		'X≠0?': 'TEST 0',
		'0!=X?': 'TEST 0',
		'0!=X': 'TEST 0',
		'0≠X': 'TEST 0',
		'0≠X?': 'TEST 0',

		'X>0?': 'TEST 1',
		'X>0': 'TEST 1',
		'0<X?': 'TEST 1',
		'0<X': 'TEST 1',

		'X<0?': 'TEST 2',
		'X<0': 'TEST 2',
		'0>X?': 'TEST 2',
		'0>X': 'TEST 2',
		
		'X>=0?': 'TEST 3',
		'X≥0?': 'TEST 3',
		'X>=0': 'TEST 3',
		'X≥0': 'TEST 3',
		'0<=X?': 'TEST 3',
		'0≤X?': 'TEST 3',
		'0<=X': 'TEST 3',
		'0≤X': 'TEST 3',

		'X<=0?': 'TEST 4',
		'X≤0?': 'TEST 4',
		'X<=0': 'TEST 4',
		'X≤0': 'TEST 4',
		'0>=X?': 'TEST 4',
		'0≥X?': 'TEST 4',
		'0>=X': 'TEST 4',
		'0≥X': 'TEST 4',

		'X=Y?': 'TEST 5',
		'X=Y': 'TEST 5',
		'Y=X?': 'TEST 5',
		'Y=X': 'TEST 5',
		
		'X!=Y?': 'TEST 6',
		'X!=Y': 'TEST 6',
 		'X≠Y': 'TEST 0',
		'X≠Y?': 'TEST 0',
		'Y!=X?': 'TEST 6',
		'Y!=X': 'TEST 6',
		'0≠Y': 'TEST 0',
		'0≠Y?': 'TEST 0',

		'X>Y?': 'TEST 7',
		'X>Y': 'TEST 7',
		'Y<X?': 'TEST 7',
		'Y<X': 'TEST 7',
		
		'X<Y?': 'TEST 8',
		'X<Y': 'TEST 8',
		'Y>X?': 'TEST 8',
		'Y>X': 'TEST 8',
		
		'X>=Y?': 'TEST 9',
		'X≥Y?': 'TEST 9',
		'X>=Y': 'TEST 9',
		'X≥Y': 'TEST 9',
		'Y<=X?': 'TEST 9',
		'Y≤X?': 'TEST 9',
		'Y<=X': 'TEST 9',
		'Y≤X': 'TEST 9',

		'STO+': 'STO +',
		'STO-': 'STO -',
		'STO*': 'STO ×',
		'STO×': 'STO ×',
		'STO/': 'STO /',
		'STO÷': 'STO /',
		'RCL+': 'RCL +',
		'RCL-': 'RCL -',
		'RCL*': 'RCL ×',
		'RCL×': 'RCL ×',
		'RCL/': 'RCL /',
		'RCL÷': 'RCL /',
		'STO ENTER': 'STO RAN#',
		'RCL ENTER': 'RCL RAN#',
		'USER STO': 'uSTO',
		'U STO': 'uSTO',
		'USER RCL': 'uRCL',
		'U RCL': 'uRCL'
	};

	oFirstPassMnemonic = {
		'SQR': 'SQR',
		'SQRT': 'SQR',
		'VX': 'SQR',
    '√X': 'SQR',
		'E^X': 'e^x',
		'EX': 'e^x',
		'10^X': '10^x',
		'10X': '10^x',
		'Y^X': 'y^x',
		'YX': 'y^x',
		'1/X': '1/x',
		'1X': '1/x',
		'CHS': 'CHS',
		'/': '÷',
		'÷': '÷',
		'DIVIDE': '÷',
		'GTO': 'GTO',
		'GOTO': 'GTO',
		'GO TO': 'GTO',
		'SIN': 'SIN',
		'COS': 'COS',
		'TAN': 'TAN',
		'EEX': 'EEX',
		'*': '×',
		'×': '×',
		'MULTIPLIED': '×',
		'TIMES': '×',
		'R/S': 'R/S',
		'RS': 'R/S',
		'STOP': 'R/S',
		'GSB': 'GSB',
		'GOSUB': 'GSB',
		'ROLL DOWN': 'R down',
		'ROLLDOWN': 'R down',
		'ROLLD': 'R down',
		'RDOWN': 'R down',
		'R DOWN': 'R down',
		'RD': 'R down',
		'R-v': 'R down',
		'RDN': 'R down',
		'R\u2193': 'R down',
		'R \u2193': 'R down',
		'R\u2B07': 'R down',
		'R \u2B07': 'R down',
		'X-><-Y': 'x><y',
		'X↔Y': 'x><y',
		'X⇔Y': 'x><y',
		'X><Y': 'x><y',
		'X~Y': 'x><y',
		'X-Y': 'x><y',
		'XY': 'x><y',
		'X<>Y': 'x><y',
		'X<->Y': 'x><y',
		'ENTER': 'ENTER',
		'ENTER↑': 'ENTER',
		'-': '-',
		'\u2212': '-',
		'MINUS': '-',
		'G': 'g',
		'STO': 'STO',
		'RCL': 'RCL',
		'.': '.',
		'SUM+': '∑+',
		'SIGMA+': '∑+',
		'Σ+': '∑+',
		'∑+': '∑+',
		'+': '+',
		'PLUS': '+',

		/* F */
		'A': 'A',
		'B': 'B',
		'C': 'C',
		'D': 'D',
		'E': 'E',
		'MATRIX': 'MATRIX',
		'FIX': 'FIX',
		'SCI': 'SCI',
		'ENG': 'ENG',
		'SOLVE': 'SOLVE',
		'LBL': 'LBL',
		'LABEL': 'LBL',
		'HYP': 'HYP',
		'DIM': 'DIM',
		'(I)': '(i)',
		'I': 'I',
		'RESULT': 'RESULT',
		'X-><-': 'x><',
		'X↔': 'x><',
		'X⇔': 'x><',
		'X><': 'x><',
		'X-': 'x><',
		'X~': 'x><',
		'X<>': 'x><',
		'DSE': 'DSE',
		'ISG': 'ISG',
		'INTEGRATE': 'INTEGRATE',
		'PSE': 'PSE',
		'CLEAR SUM': 'CLEAR ∑',
		'CL SUM': 'CLEAR ∑',
		'SUM': 'CLEAR ∑',
		'∑': 'CLEAR ∑',
		'CLEAR SIGMA': 'CLEAR ∑',
		'CLEAR ∑': 'CLEAR ∑',
		'CL SIGMA': 'CLEAR ∑',
		'CL ∑': 'CLEAR ∑',
		'SIGMA': 'CLEAR ∑',
		'CLEAR REG': 'CLEAR REG',
		'CL REG': 'CLEAR REG',
		'REG': 'CLEAR REG',
		'CLEAR PREFIX': 'CLEAR PREFIX',
		'CL PREFIX': 'CLEAR PREFIX',
		'PREFIX': 'CLEAR PREFIX',
		'RAN#': 'RAN#',
		'->R': '>R',
		'→R': '>R',
		'>R': '>R',
		'-R': '-R',
		'>H.MS': '>H.MS',
		'-H.MS': '>H.MS',
		'->H.MS': '>H.MS',
		'→H.MS': '>H.MS',
		'>HMS': '>H.MS',
		'-HMS': '>H.MS',
		'->HMS': '>H.MS',
		'→HMS': '>H.MS',
		'HMS': '>H.MS',
		'->RAD': '>RAD',
		'→RAD': '>RAD',
		'-RAD': '>RAD',
		'>RAD': '>RAD',
		'RE-><-IM': 'Re><Im',
		'RE↔IM': 'Re><Im',
		'RE⇔IM': 'Re><Im',
    'RE><IM': 'Re><Im',
		'RE<>IM': 'Re><Im',
		'RE-IM': 'Re><Im',
		'RE~IM': 'Re><Im',
		'R-I': 'Re><Im',
		'RI': 'Re><Im',
		'FRAC': 'FRAC',
		'X!': 'x!',
		'!': 'x!',
		'Y,R': 'y,r',
		'Ŷ,R': 'y,r',
		'Y^,R': 'y,r',
		'YR': 'y,r',
		'L.R.': 'L.R.',
		'LR': 'L.R.',
		'PY,X': 'Py,x',
		'P Y,X': 'Py,x',
		'PYX': 'Py,x',

		/* G */
		'X^2': 'x^2',
		'X2': 'x^2',
		'X²': 'x^2',
		'LN': 'LN',
		'LOG': 'LOG',
		'%': '%',
		'd%': 'Delta%',
		'Δ%': 'Delta%',
		'DELTA%': 'Delta%',
		'DELTA %': 'Delta%',
		'ABS': 'ABS',
		'DEG': 'DEG',
		'RAD': 'RAD',
		'GRD': 'GRD',
		'GRAD': 'GRD',
		'X<=Y?': 'x<=y?',
		'X≤Y?': 'x<=y?',
		'X<=Y': 'x<=y?',
		'X≤Y': 'x<=y?',
		'HYP^-1': 'HYP^-1',
		'HYP-1': 'HYP^-1',
		'HYP1': 'HYP^-1',
		'SIN^-1': 'SIN^-1',
		'SIN-1': 'SIN^-1',
		'SIN1': 'SIN^-1',
		'COS^-1': 'COS^-1',
		'COS-1': 'COS^-1',
		'COS1': 'COS^-1',
		'TAN^-1': 'TAN^-1',
		'TAN-1': 'TAN^-1',
		'TAN1': 'TAN^-1',
		'PI': 'pi',
		'Π': 'pi',
		'SF': 'SF',
		'SETFLAG': 'SF',
		'SET FLAG': 'SF',
		'CF': 'CF',
		'CLFLAG': 'CF',
		'CL FLAG': 'CF',
		'CLEARFLAG': 'CF',
		'CLEAR FLAG': 'CF',
		'F?': 'F?',
		'FLAG?': 'F?',
		'X=0?': 'x=0?',
		'X=0': 'x=0?',
		'P/R': 'P/R',
		'PR': 'P/R',
		'RTN': 'RTN',
		'ROLL UP': 'R up',
		'ROLLUP': 'R up',
		'ROLLU': 'R up',
		'RUP': 'R up',
		'R UP': 'R up',
		'RU': 'R up',
		'R \u2191': 'R up',
		'R\u2191': 'R up',
		'R \u2B06': 'R up',
		'R\u2B06': 'R up',
		'R^': 'R up',
		'RND': 'RND',
		'CLX': 'CLx',
		'LSTX': 'LSTx',
		'LST X': 'LSTx',
		'LASTX': 'LSTx',
		'LAST X': 'LSTx',
		'->P': '>P',
		'→P': '>P',
		'-P': '>P',
		'>P': '>P',
		'->H': '>H',
		'→H': '>H',
		'-H': '>H',
		'>H': '>H',
		'->DEG': '>DEG',
		'→DEG': '>DEG',
		'-DEG': '>DEG',
		'>DEG': '>DEG',
		'TEST': 'TEST',
		'INT': 'INT',
		'MEM': 'MEM',
		'MEAN': 'x mean',
		'XMEAN': 'x mean',
		'X (MEAN)': 'x mean',
		'X MEAN': 'x mean',
		'S': 's',
		'SUM-': '∑-',
		'SIGMA-': '∑-',
		'Σ-' : '∑-',
		'∑-': '∑-',
		'CY,X': 'Cy,x',
		'C Y,X': 'Cy,x',
		'CYX': 'Cy,x',

		'USTO': 'uSTO',
		'URCL': 'uRCL'
	};

	oHP15cCommandPrefix = {
		'A': 'f',
		'B': 'f',
		'C': 'f',
		'D': 'f',
		'E': 'f',
		'MATRIX': 'f',
		'FIX': 'f',
		'SCI': 'f',
		'ENG': 'f',
		'SOLVE': 'f',
		'LBL': 'f',
		'HYP': 'f',
		'DIM': 'f',
		'(i)': 'f',
		'I': 'f',
		'RESULT': 'f',
		'x><': 'f',
		'DSE': 'f',
		'ISG': 'f',
		'INTEGRATE': 'f',
		'PSE': 'f',
		'CLEAR ∑': 'f',
		'CLEAR REG': 'f',
		'CLEAR PREFIX': 'f',
		'RAN#': 'f',
		'>R': 'f',
		'>H.MS': 'f',
		'>RAD': 'f',
		'Re><Im': 'f',
		'FRAC': 'f',
		'x!': 'f',
		'y,r': 'f',
		'L.R.': 'f',
		'Py,x': 'f',

		'x^2': 'g',
		'LN': 'g',
		'LOG': 'g',
		'%': 'g',
		'Delta%': 'g',
		'ABS': 'g',
		'DEG': 'g',
		'RAD': 'g',
		'GRD': 'g',
		'x<=y?': 'g',
		'HYP^-1': 'g',
		'SIN^-1': 'g',
		'COS^-1': 'g',
		'TAN^-1': 'g',
		'pi': 'g',
		'SF': 'g',
		'CF': 'g',
		'F?': 'g',
		'x=0?': 'g',
		'P/R': 'g',
		'RTN': 'g',
		'R up': 'g',
		'RND': 'g',
		'CLx': 'g',
		'LSTx': 'g',
		'>P': 'g',
		'>H': 'g',
		'>DEG': 'g',
		'TEST': 'g',
		'INT': 'g',
		'MEM': 'g',
		'x mean': 'g',
		's': 'g',
		'∑-': 'g',
		'Cy,x': 'g'
	};

	oHP15cCommandPartLabel = {};

	oHP15cCommandPartRegister = {
		'(i)': {
			'code': '24'
		},
		'I': {
			'code': '25'
		}
	};

	// add 0 ... 9 and .0 ... .9 to firstpass label register
	for (i = 0; i <= 9; i++) {
		sIdentifier = i.toString();
		oFirstPassMnemonic[sIdentifier] = sIdentifier;
		oHP15cCommandPartLabel[sIdentifier] = { 'code': ' ' + sIdentifier };
		oHP15cCommandPartRegister[sIdentifier] = { 'code': ' ' + sIdentifier };

		sIdentifier = '.' + i.toString();
		oFirstPassMnemonic[sIdentifier] = sIdentifier;
		oFirstPassMnemonic[',' + i.toString()] = sIdentifier;
		oFirstPassMnemonic['1' + i.toString()] = sIdentifier;
		oHP15cCommandPartLabel[sIdentifier] = { 'code': sIdentifier };
		oHP15cCommandPartRegister[sIdentifier] = { 'code': sIdentifier };
	}

	oHP15cCommandPartRegisterArithmetic = {
		'÷': {
			'code': '10'
		},
		'×': {
			'code': '20'
		},
		'-': {
			'code': '30'
		},
		'+': {
			'code': '40'
		}
	};

	oHP15cCommandPartTrigonometry = {
		'SIN': {
			'code': '23'
		},
		'COS': {
			'code': '24'
		},
		'TAN': {
			'code': '25'
		}
	};

	oHP15cCommand = {
		'SQR': {
			'code': '11'
		},
		'e^x': {
			'code': '12'
		},
		'10^x': {
			'code': '13'
		},
		'y^x': {
			'code': '14'
		},
		'1/x': {
			'code': '15'
		},
		'CHS': {
			'code': '16'
		},
		'÷': {
			'code': '10'
		},

		'GTO': {
			'code': '22',
			'I': {
				'code': '25'
			}
		},
		'EEX': {
			'code': '26'
		},
		'×': {
			'code': '20'
		},

		'R/S': {
			'code': '31'
		},
		'GSB': {
			'code': '32',
			'I': {
				'code': '25'
			}
		},
		'R down': {
			'code': '33'
		},
		'x><y': {
			'code': '34'
		},
		'ENTER': {
			'code': '36'
		},
		'-': {
			'code': '30'
		},

		'f': {
			'code': '42'
		},
		'g': {
			'code': '43'
		},
		'STO': {
			'code': '44',
			'RAN#': {
				'code': '36'
			},
			'RESULT': {
				'code': '26'
			},
			'g': {
				'code': '43',
				'(i)': {
					'code': '24'
				}
			},
			'MATRIX': {
				'code': '16'
			}
		},
		'uSTO': {
			'code': '44',
			'comment': 'USER mode',
			'(i)': {
				'code': '25 u'
			}
		},
		'RCL': {
			'code': '45',
			'RAN#': {
				'code': '36'
			},
			'RESULT': {
				'code': '26'
			},
			'g': {
				'code': '43',
				'(i)': {
					'code': '24'
				}
			},
			'MATRIX': {
				'code': '16'
			},
			'DIM': {
				'code': '23',
				'(i)': {
					'code': '24'
				}
			}
		},
		'uRCL': {
			'code': '45',
			'comment': 'USER mode',
			'(i)': {
				'code': '25 u'
			}
		},
		'.': {
			'code': '48'
		},
		'∑+': {
			'code': '49'
		},
		'+': {
			'code': '40'
		},

		/* F */
		'MATRIX': {
			'code': '16',
			'0': {
				'code': ' 0' /*,
				'comment': 'Dimensions all matrices to 0x0.' */
			},
			'1': {
				'code': ' 1' /*,
				'comment': 'Sets row and column numbers in R0 and R1 to 1.' */
			},
			'2': {
				'code': ' 2' /*,
				'comment': 'Transform ZP into Z(tilde).' */
			},
			'3': {
				'code': ' 3' /*,
				'comment': 'Transforms Z(tilde) into ZP.' */
			},
			'4': {
				'code': ' 4' /*,
				'comment': 'Calculate transpose of matrix specified in X-register.' */
			},
			'5': {
				'code': ' 5' /*,
				'comment': 'Multiplies transpose of matrix specified in Y-register with matrix specified in X-register. Stores in result matrix.' */
			},
			'6': {
				'code': ' 6' /*,
				'comment': 'Calculates residual in result matrix.' */
			},
			'7': {
				'code': ' 7' /*,
				'comment': 'Calculates row norm of matrix specified in X-register.' */
			},
			'8': {
				'code': ' 8' /*,
				'comment': 'Calculates Frobenius or Euclidean norm of matrix specified in X-register.' */
			},
			'9': {
				'code': ' 9' /*,
				'comment': 'Calculates determinant of matrix specified in X-register, Place LU in result matrix.' */
			}
		},
		'FIX': {
			'code': ' 7',
			'I': {
				'code': '25'
			}
		},
		'SCI': {
			'code': ' 8',
			'I': {
				'code': '25'
			}
		},
		'ENG': {
			'code': ' 9',
			'I': {
				'code': '25'
			}
		},
		'SOLVE': {
			'code': '10'
		},

		'LBL': {
			'code': '21'
		},
		'HYP': {
			'code': '22'
		},
		'DIM': {
			'code': '23',
			'(i)': {
				'code': '24' /*,
				'comment': 'Data Storage' */
			},
			'I': {
				'code': '25' /*,
				'comment': 'Matrix' */
			}
		},
		'I': {
			'code': '25'
		},
		'RESULT': {
			'code': '26'
		},
		'x><': {
			'code': ' 4'
		},
		'DSE': {
			'code': ' 5'
		},
		'ISG': {
			'code': ' 6'
		},
		'INTEGRATE': {
			'code': '20'
		},

		'PSE': {
			'code': '31'
		},
		'CLEAR ∑': {
			'code': '32'
		},
		'CLEAR REG': {
			'code': '34'
		},
		'RAN#': {
			'code': '36'
		},
		'>R': {
			'code': ' 1'
		},
		'>H.MS': {
			'code': ' 2'
		},
		'>RAD': {
			'code': ' 3'
		},
		'Re><Im': {
			'code': '30'
		},

		'FRAC': {
			'code': '44'
		},
		'x!': {
			'code': ' 0'
		},
		'y,r': {
			'code': '48'
		},
		'L.R.': {
			'code': '49'
		},
		'Py,x': {
			'code': '40'
		},

		/* G */
		'x^2': {
			'code': '11'
		},
		'LN': {
			'code': '12'
		},
		'LOG': {
			'code': '13'
		},
		'%': {
			'code': '14'
		},
		'Delta%': {
			'code': '15'
		},
		'ABS': {
			'code': '16'
		},
		'DEG': {
			'code': ' 7'
		},
		'RAD': {
			'code': ' 8'
		},
		'GRD': {
			'code': ' 9'
		},
		'x<=y?': {
			'code': '10'
		},

		'HYP^-1': {
			'code': '22'
		},
		'SIN^-1': {
			'code': '23'
		},
		'COS^-1': {
			'code': '24'
		},
		'TAN^-1': {
			'code': '25'
		},
		'pi': {
			'code': '26'
		},
		'SF': {
			'code': ' 4',
			'I': {
				'code': '25'
			}
		},
		'CF': {
			'code': ' 5',
			'I': {
				'code': '25'
      }
		},
		'F?': {
			'code': ' 6',
			'I': {
				'code': '25'
      }
		},
		'x=0?': {
			'code': '20'
		},

		'RTN': {
			'code': '32'
		},
		'R up': {
			'code': '33'
		},
		'RND': {
			'code': '34'
		},
		'CLx': {
			'code': '35'
		},
		'LSTx': {
			'code': '36'
		},
		'>P': {
			'code': ' 1'
		},
		'>H': {
			'code': ' 2'
		},
		'>DEG': {
			'code': ' 3'
		},
		'TEST': {
			'code': '30',
			'0': {
				'code': ' 0',
				'comment': 'x!=0?'
      },
			'1': {
				'code': ' 1',
				'comment': 'x>0?'
			},
			'2': {
				'code': ' 2',
				'comment': 'x<0?'
			},
			'3': {
				'code': ' 3',
				'comment': 'x>=0?'
			},
			'4': {
				'code': ' 4',
				'comment': 'x<=0?'
			},
			'5': {
				'code': ' 5',
				'comment': 'x=y?'
			},
			'6': {
				'code': ' 6',
				'comment': 'x!=y?'
			},
			'7': {
				'code': ' 7',
				'comment': 'x>y?'
			},
			'8': {
				'code': ' 8',
				'comment': 'x<y?'
			},
			'9': {
				'code': ' 9',
				'comment': 'x>=y?'
			}
		},

		'INT': {
			'code': '44'
		},
		'x mean': {
			'code': ' 0'
		},
		's': {
			'code': '48'
		},
		'∑-': {
			'code': '49'
		},
		'Cy,x': {
			'code': '40'
		}
	};

	// add register to register arithmetic
	for (j in oHP15cCommandPartRegister) {
		if (oHP15cCommandPartRegister.hasOwnProperty(j)) {
			for (i in oHP15cCommandPartRegisterArithmetic) {
				if (oHP15cCommandPartRegisterArithmetic.hasOwnProperty(i)) {
					oHP15cCommandPartRegisterArithmetic[i][j] = oHP15cCommandPartRegister[j];
				}
			}
		}
	}

	// add register to sto rcl x>< dse isg
	for (i in oHP15cCommandPartRegister) {
		if (oHP15cCommandPartRegister.hasOwnProperty(i)) {
			oHP15cCommand.STO[i] = oHP15cCommandPartRegister[i];
			oHP15cCommand.RCL[i] = oHP15cCommandPartRegister[i];
			oHP15cCommand['x><'][i] = oHP15cCommandPartRegister[i];
			oHP15cCommand.DSE[i] = oHP15cCommandPartRegister[i];
			oHP15cCommand.ISG[i] = oHP15cCommandPartRegister[i];
		}
	}

	// add register arithmetic to sto and rcl
	for (i in oHP15cCommandPartRegisterArithmetic) {
		if (oHP15cCommandPartRegisterArithmetic.hasOwnProperty(i)) {
			oHP15cCommand.STO[i] = oHP15cCommandPartRegisterArithmetic[i];
			oHP15cCommand.RCL[i] = oHP15cCommandPartRegisterArithmetic[i];
		}
	}

	// add key 0 ... 9
	for (i = 0; i <= 9; i++) {
		sIdentifier = i.toString();

		// key 0 ... 9
		oHP15cCommand[sIdentifier] = { 'code': ' ' + i.toString()};

		// fix sci eng
		oHP15cCommand.FIX[sIdentifier] = { 'code': ' ' + i.toString() };
		oHP15cCommand.SCI[sIdentifier] = { 'code': ' ' + i.toString() };
		oHP15cCommand.ENG[sIdentifier] = { 'code': ' ' + i.toString() };

		// sf cf f?
		/*
		sComment = 'User Flag';
		switch (i) {
		case 8:
			sComment = 'Complex Mode';
			break;
		case 9:
			sComment = 'Overflow Condition';
			break;
		}
		*/
		oHP15cCommand.SF[sIdentifier] = { 'code': ' ' + i.toString() /*, 'comment': sComment */ };
		oHP15cCommand.CF[sIdentifier] = { 'code': ' ' + i.toString() /*, 'comment': sComment */ };
		oHP15cCommand['F?'][sIdentifier] = { 'code': ' ' + i.toString() /*, 'comment': sComment */ };
	}

	// add letter to command label sto sto_g sto_matrix usto rcl rcl_g rcl_matrix rcl_dim urcl dim result x>< dse isg
	oLetter = {'1': 'A', '2': 'B', '3': 'C', '4': 'D', '5': 'E'};
	for (i in oLetter) {
		if (oLetter.hasOwnProperty(i)) {
			oHP15cCommandPartLabel[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand[oLetter[i]] = { 'code': '1' + i, 'comment': 'GSB ' + oLetter[i] };
			oHP15cCommand.STO[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.STO.g[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.STO.MATRIX[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.uSTO[oLetter[i]] = { 'code': '1' + i + ' u'};
			oHP15cCommand.RCL[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.RCL.g[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.RCL.MATRIX[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.RCL.DIM[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.uRCL[oLetter[i]] = { 'code': '1' + i + ' u'};
			oHP15cCommand.DIM[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.RESULT[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand['x><'][oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.DSE[oLetter[i]] = { 'code': '1' + i };
			oHP15cCommand.ISG[oLetter[i]] = { 'code': '1' + i };
		}
	}

	// add label to lbl gto gsb solve integrate
	for (i in oHP15cCommandPartLabel) {
		if (oHP15cCommandPartLabel.hasOwnProperty(i)) {
			oHP15cCommand.LBL[i] = oHP15cCommandPartLabel[i];
			oHP15cCommand.GTO[i] = oHP15cCommandPartLabel[i];
			oHP15cCommand.GSB[i] = oHP15cCommandPartLabel[i];
			oHP15cCommand.SOLVE[i] = oHP15cCommandPartLabel[i];
			oHP15cCommand.INTEGRATE[i] = oHP15cCommandPartLabel[i];
		}
	}

	// add trigonometry
	for (i in oHP15cCommandPartTrigonometry) {
		if (oHP15cCommandPartTrigonometry.hasOwnProperty(i)) {
			oHP15cCommand[i] = oHP15cCommandPartTrigonometry[i];
			oHP15cCommand.HYP[i] = oHP15cCommandPartTrigonometry[i];
			oHP15cCommand['HYP^-1'][i] = oHP15cCommandPartTrigonometry[i];
		}
	}

	this.convert = function (sMnemonics) {

		var	i,
			aLinesIn,
			aElementsIn,
			aMenmonic,
			sDisplay,
			sComment,
			sRemarks,
			sPrefix,
			fValue,
			iValue,
			aNumber,
			oInstruction,
			sKeycode,
			iLineCount,
			iLineNumber,
			bLoop,
			bParseOK,
			sData,
			iElementsInCount,
			aErrorMessage,
			aArgument,
			sOrdinal;

		aFormatedString = {
			'OutputLine': '{0} { {1} } {2}\n',
			'Error': {
				'InLine': '<span class="MCerror">\u2BA4 Error in line {0} </span>\n',
				'CommandUnknown' : 'The command <span class="MCcommand">{0}</span> is unknown.\nValid commands are:\n{1}\n',
				'NoArguments': 'The {0} argument is missing: <span class="MCcommand">{1}</span> can not be called with no arguments.\nValid arguments are:\n{2}\n',
				'ArgumentMissing': 'The {0} argument is missing: <span class="MCcommand">{1}</span> is valid only with arguments like:\n{2}\n',
				'ArgumentInvalid': 'The {0} argument is invalid: <span class="MCargument">{1}</span> is not a parameter of <span class="MCcommand">{2}</span>.\nValid parameters are:\n{3}\n'
			}
    };

		sKeycode = '';
		iLineCount = 0;
		iLineNumber = 0;
		bParseOK = false;

		sMnemonics = sMnemonics.ltrim();
		aLinesIn = sMnemonics.split(sMnemonics.search('\r\n') >= 0 ? '\r\n' : '\n');

		function fillLeftSpace(s) {
			while (s.length < 11) {
				s = ' ' + s;
			}
			return s;
		}

		function incAndGetLineNumber() {
			iLineNumber++;
			return ('000' + iLineNumber.toString()).slice(-3);
		}

		function getNumber(s) {
			var	i,
				sReturn,
				bNegative;

			sReturn = '';
			bNegative = s.charAt(0) === '-';
			if (s.charAt(0) === '-' || s.charAt(0) === '+') {
				s = s.slice(1);
			}
			for (i = 0; i < s.length; i++) {
				sReturn += aFormatedString.OutputLine.format(incAndGetLineNumber(), fillLeftSpace(oHP15cCommand[s.charAt(i)].code), s.charAt(i));
			}
			if (bNegative) {
				sReturn += aFormatedString.OutputLine.format(incAndGetLineNumber(), fillLeftSpace(oHP15cCommand.CHS.code), 'CHS');
			}
			return sReturn;
		}

		function isCompleteInstruction(o) {
			var i,
				bComplete;
			bComplete = true;
			for (i in o) {
				if (o.hasOwnProperty(i) && i !== 'code' && i !== 'comment') {
					bComplete = false;
				}
			}
			return bComplete;
		}

		while (iLineCount < aLinesIn.length) {

			aLinesIn[iLineCount] = aLinesIn[iLineCount].replace(/\s+/g, ' ');

			if (aLinesIn[iLineCount].ltrim().length !== 0) {

				aElementsIn = aLinesIn[iLineCount].trim().split(' ');

				// for all elements in aElementsIn if not one mnemonic per line
				do {
					aMenmonic = [];
					bParseOK = false;
					bLoop = true;
					oInstruction = oHP15cCommand;
					iElementsInCount = 0;

					// delete prefix f or g
					if (aElementsIn[0].toUpperCase() === 'F' || aElementsIn[0].toUpperCase() === 'G') {
						aElementsIn.shift();
					}
					
					// recombine shortcuts
					if (aElementsIn.length !== 0 && oRecombine.hasOwnProperty(aElementsIn[0].toUpperCase())) {
						aElementsIn[0] = oRecombine[aElementsIn[0].toUpperCase()];
						aLinesIn[iLineCount] = aElementsIn.join(' ');
						aElementsIn = aLinesIn[iLineCount].ltrim().split(' ');
					} else if (aElementsIn.length > 1 && oRecombine.hasOwnProperty(aElementsIn[0].toUpperCase() + ' ' + aElementsIn[1].toUpperCase())) {
						aElementsIn[1] = oRecombine[aElementsIn[0].toUpperCase() + ' ' + aElementsIn[1].toUpperCase()];
						aElementsIn.shift();
						aLinesIn[iLineCount] = aElementsIn.join(' ');
						aElementsIn = aLinesIn[iLineCount].ltrim().split(' ');
					}
	
					while (bLoop && aElementsIn.length > iElementsInCount && aElementsIn[iElementsInCount].length !== 0) {
						bLoop = false;
						sData = aElementsIn[iElementsInCount].toUpperCase();
						if (oFirstPassMnemonic.hasOwnProperty(sData) && oInstruction[oFirstPassMnemonic[sData]]) {
							aMenmonic.push(oFirstPassMnemonic[sData]);
							oInstruction = oInstruction[oFirstPassMnemonic[sData]];
							iElementsInCount++;
							bLoop = true;
						} else if (aElementsIn.length > iElementsInCount + 1) {
							sData += ' ' + aElementsIn[iElementsInCount + 1].toUpperCase();
							if (oFirstPassMnemonic.hasOwnProperty(sData) && oInstruction[oFirstPassMnemonic[sData]]) {
								aMenmonic.push(oFirstPassMnemonic[sData]);
								oInstruction = oInstruction[oFirstPassMnemonic[sData]];
								iElementsInCount += 2;
								bLoop = true;
							}
						}
					}

					if (aMenmonic.length !== 0 && isCompleteInstruction(oInstruction)) {
	
						// delete parsed items
						while (iElementsInCount > 0) {
							aElementsIn.shift();
							iElementsInCount--;
						}

						aDisplay = [];
						sComment = '';
						sRemarks = bOMPL ? aElementsIn.join(' ') : '';
						sPrefix = '';
						oInstruction = oHP15cCommand;
						for (i = 0; i < aMenmonic.length; i++) {
							if (oInstruction[aMenmonic[i]]) {
								oInstruction = oInstruction[aMenmonic[i]];
								if (i === 0 && oHP15cCommandPrefix[aMenmonic[i]]) {
									aDisplay.push(oHP15cCommand[oHP15cCommandPrefix[aMenmonic[i]]].code);
									if (bPrefixKey) {
										sPrefix = oHP15cCommandPrefix[aMenmonic[i]] + ' ';
									}
								}
								aDisplay.push(oInstruction.code);
								if (oInstruction.comment && oInstruction.comment.length !== 0) {
									if (sComment.length !== 0) {
										sComment += ' ';
									}
									sComment += oInstruction.comment;
								}
							}
						}

						// maintain simulator style, replace . with 48
//						if (bSimulator) {
//							for (i = 0; i < aDisplay.length; i++) {
//								aDisplay[i] = aDisplay[i].replace('.', oHP15cCommand['.'].code + '  ');
//							}
//						}

						sKeycode += aFormatedString.OutputLine.format(
							incAndGetLineNumber(),
							fillLeftSpace(aDisplay.join(' ')),
							(sPrefix + aMenmonic.join(' ') + ' ' + sComment + ' ' + sRemarks).entityfy().rtrim()
						);
						bParseOK = true;

					} else {

						if (aElementsIn.length !== 0) {
							// remove leading comma or point and replace comma with point
							if (aElementsIn[0].indexOf(',') < aElementsIn[0].indexOf('.')) {
								aElementsIn[0] = aElementsIn[0].replace(/,/g, '');
							} else if (aElementsIn[0].indexOf(',') > aElementsIn[0].indexOf('.')) {
								aElementsIn[0] = aElementsIn[0].replace(/\./g, '');
								aElementsIn[0] = aElementsIn[0].replace(/,/g, '.');
							} 
							
							if (aElementsIn[0].match(/^([+-]?\d*.?\d*(e)?[+-]?\d+$)/i)) {
								fValue = parseFloat(aElementsIn[0]);
								if (!isNaN(fValue)) {
									aNumber = aElementsIn[0].replace(/ᴇ/g, 'E').toUpperCase().split('E');
									sKeycode += getNumber(aNumber[0]);
									if (aNumber.length === 2) {
										sKeycode += aFormatedString.OutputLine.format(incAndGetLineNumber(), fillLeftSpace(oHP15cCommand.EEX.code), 'EEX');
										if (aNumber[1].charAt(0) === '+') {
											aNumber[1] = aNumber[1].substr(1);
										}
										sKeycode += getNumber(aNumber[1]);
									}
									bParseOK = true;
								} else if (aElementsIn[0].charAt(0).toUpperCase() === 'E') {

									iValue = parseInt(aElementsIn[0].slice(1), 10);
									if (!isNaN(iValue)) {
										sKeycode += aFormatedString.OutputLine.format(incAndGetLineNumber(), fillLeftSpace(oHP15cCommand.EEX.code), 'EEX');
										sKeycode += getNumber(aElementsIn[0].slice(1));
										bParseOK = true;
									}
								}
								if (bParseOK) {
									aElementsIn.shift();
								}
							}
							
						}
					
					}

					// error handling
					if (!bParseOK) {
						if (bOMPL) {
						
							// get all possible arguments
							aArgument = [];
							for (i in oInstruction) {
								if (oInstruction.hasOwnProperty(i) && i !== 'code' && i !== 'comment') {
									aArgument.push('<span class="MCargument">' + i.entityfy() +
                    (oInstruction[i].comment && oInstruction[i].comment.length !== 0 ? ' (' + oInstruction[i].comment.entityfy() + ')' : '') +
                    '</span>');
								}
							}

							if (0 !== iLineNumber) {
								sKeycode += '';
							}

							sKeycode += aElementsIn.join(' ') + '\n';
              for (i = 0; i < iElementsInCount; i++) {
									sKeycode += aElementsIn[i].replace(/./g, ' ') + ' ';
							}
							sKeycode += aFormatedString.Error.InLine.format(incAndGetLineNumber());
							if (0 === iElementsInCount) {
 								sKeycode += aFormatedString.Error.CommandUnknown.format(
									aElementsIn[0].toUpperCase(),
									aArgument.join(', ')
								);
							} else {

								sOrdinal = (function (i) { return i < 3 ? ['1st', '2nd', '3rd'][i] : (i + 1).toString() + 'th'; })(iElementsInCount);

								if (aElementsIn.length <= iElementsInCount) {
									sKeycode += 
										1 === iElementsInCount ?
										aFormatedString.Error.NoArguments.format(sOrdinal, aMenmonic.join(' '), aArgument.join(', ')) :
										aFormatedString.Error.ArgumentMissing.format(sOrdinal, aMenmonic.join(' '), aArgument.join(', '));
								} else {
									sKeycode += aFormatedString.Error.ArgumentInvalid.format(sOrdinal, aElementsIn[iElementsInCount].toUpperCase(), aMenmonic.join(' '), aArgument.join(', '));
								}
							}
							sKeycode += '\n';

						} else {
							sKeycode += aFormatedString.OutputLine.format(incAndGetLineNumber(), '<span class="MCerror">-- ERROR --</span>', aElementsIn.shift());
						}
					}
				} while (!bOMPL && aElementsIn.length > 0);
			}
			iLineCount++;
		}
    return sKeycode;
	};
};
