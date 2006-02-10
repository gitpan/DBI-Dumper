package DBI::Dumper::C;

use strict;
use warnings;

our $VERSION = '1.00';

use Inline 
	C => 'DATA',
	VERSION => '1.00',
	NAME => 'DBI::Dumper::C';

1;

__DATA__

=pod

=cut

__C__

SV *escape;
char *escape_ptr;
STRLEN escape_len = 0;

SV *terminator;
char *terminator_ptr;
STRLEN terminator_len = 0;

SV *left_delim;
char *left_delim_ptr;
STRLEN left_delim_len = 0;

SV *right_delim;
char *right_delim_ptr;
STRLEN right_delim_len = 0;

void init(SV *self_ref) {
	HV *self;

	/* dereference self */
	self = (HV *)SvRV(self_ref);

	/* values for self members */
	escape = *hv_fetch(self, "escape", 6, 0);
	terminator = *hv_fetch(self, "terminator", 10, 0);
	left_delim = *hv_fetch(self, "left_delim", 10, 0);
	right_delim = *hv_fetch(self, "right_delim", 11, 0);

	/* get string values */
	if(SvOK(escape)) {
		escape_ptr = SvPV( escape, escape_len );
	}

	if(SvOK(terminator)) {
		terminator_ptr = SvPV( terminator, terminator_len );
	}

	if(SvOK(left_delim)) {
		left_delim_ptr = SvPV( left_delim, left_delim_len );
	}

	if(SvOK(right_delim)) {
		right_delim_ptr = SvPV( right_delim, right_delim_len );
	}
}


SV *build(SV *self_ref, SV *row_ref) {
	HV *self;
	AV *row;
	int row_len;
	SV *data; /* return value */

	I32 col_iter;

	/* dereference self and row */
	self = (HV *)SvRV(self_ref);
	row = (AV *)SvRV(row_ref);

	/* create return value */
	data = newSVpv("", 0);

	row_len = av_len(row);

	for(col_iter = 0; col_iter <= row_len; col_iter++) {
		SV *col;
		char *col_ptr;
		STRLEN col_len;

		/* fetch column data and string */
		col = *av_fetch(row, col_iter, 0);
		col_ptr = SvPV(col, col_len);

		/* append terminator to string if not first column */
		if(col_iter > 0) {
			sv_catpvn(data, terminator_ptr, terminator_len);
		}

		if(SvOK(left_delim)) {
			sv_catsv(data, left_delim);
		}
		
		/* do escaping and append to data */
		if(SvOK(escape)) {
			int i;
			for(i = 0; i < col_len; ) {
				char *c = col_ptr + i;
				int shift_len = 1;
				int keep_going = 1;

				/* escape embedded escapes */
				if(
					escape_len > 0 &&
					strncmp(c, escape_ptr, escape_len) == 0
				) {
					sv_catsv(data, escape);
					shift_len = escape_len;
					keep_going = 0;
				}

				/* escape embedded terminators */
				if(
					left_delim_len == 0 && /* don't have to escape */
					right_delim_len == 0 && /* if I have enclosures */
					keep_going &&
					terminator_len > 0 &&
					strncmp(c, terminator_ptr, terminator_len) == 0
				) {
					sv_catsv(data, escape);
					shift_len = terminator_len;
					keep_going = 0;
				}

				/* escape embedded enclosures */
				if(
					keep_going &&
					left_delim_len > 0 && 
					SvOK(left_delim) && 
					strncmp(c, left_delim_ptr, left_delim_len) == 0
				) {
					sv_catsv(data, escape);
					shift_len = left_delim_len;
					keep_going = 0;
				}

				if(
					keep_going &&
					right_delim_len > 0 && 
					SvOK(right_delim) && 
					strncmp(c, right_delim_ptr, right_delim_len) == 0
				) {
					sv_catsv(data, escape);
					shift_len = right_delim_len;
					keep_going = 0;
				}

				sv_catpvn(data, c, shift_len);
				i += shift_len;
			}
		}
		else {
			sv_catsv(data, col);
		}

		if(SvOK(right_delim)) {
			sv_catsv(data, right_delim);
		}
	}
	sv_catpvn(data, "\n", 1);

	return data;
}

