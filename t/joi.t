use lib '.';
use t::Helper;
use JSON::Validator::Joi 'joi';
use Storable 'dclone';

isa_ok +joi->validator, 'JSON::Validator::Schema';
is_deeply +joi->validator->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

is_deeply(
  edj(joi->object->strict->props(
    age       => joi->integer->min(0)->max(200),
    alphanum  => joi->alphanum->length(12),
    color     => joi->string->min(2)->max(12)->pattern('^\w+$'),
    date_time => joi->iso_date,
    email     => joi->string->email->required,
    exists    => joi->boolean,
    lc        => joi->lowercase,
    name      => joi->string->min(1),
    pos       => joi->positive,
    token     => joi->token,
    uc        => joi->uppercase,
    uri       => joi->uri,
  )),
  {
    type       => 'object',
    required   => ['email'],
    properties => {
      age       => {type => 'integer', minimum   => 0,  maximum   => 200},
      alphanum  => {type => 'string',  minLength => 12, maxLength => 12, pattern => '^\w*$'},
      color     => {type => 'string',  minLength => 2,  maxLength => 12, pattern => '^\w+$'},
      date_time => {type => 'string',  format    => 'date-time'},
      email     => {type => 'string',  format    => 'email'},
      exists    => {type => 'boolean'},
      lc        => {type => 'string', pattern   => '^\p{Lowercase}*$'},
      name      => {type => 'string', minLength => 1},
      pos       => {type => 'number', minimum   => 0},
      token     => {type => 'string', pattern   => '^[a-zA-Z0-9_]+$'},
      uc        => {type => 'string', pattern   => '^\p{Uppercase}*$'},
      uri       => {type => 'string', format    => 'uri'},
    },
    additionalProperties => false
  },
  'generated correct object schema'
);

is_deeply(
  edj(joi->array->min(0)->max(10)->strict->items(joi->integer->negative)),
  {
    additionalItems => false,
    type            => 'array',
    minItems        => 0,
    maxItems        => 10,
    items           => {type => 'integer', maximum => 0}
  },
  'generated correct array schema'
);

is_deeply(edj(joi->string->enum([qw(1.0 2.0)])), {type => 'string', enum => [qw(1.0 2.0)]}, 'enum for string');

is_deeply(edj(joi->integer->enum([qw(1 2 4 8 16)])), {type => 'integer', enum => [qw(1 2 4 8 16)]}, 'enum for integer');

joi_ok(
  {age => 34, email => 'jhthorsen@cpan.org', name => 'Jan Henning Thorsen'},
  joi->props(
    age   => joi->integer->min(0)->max(200),
    email => joi->string->email->required,
    name  => joi->string->min(1),
  ),
);

joi_ok(
  {age => -1, name => 'Jan Henning Thorsen'},
  joi->props(
    age   => joi->integer->min(0)->max(200),
    email => joi->string->email->required,
    name  => joi->string->min(1),
  ),
  E('/age',   '-1 < minimum(0)'),
  E('/email', 'Missing property.'),
);

note 'test that compile and not compile generates same strict result';
my $strict_obj = joi->object->strict->props({ns => joi->string->required});
joi_ok({ns => 'plop', toto => 'plouf'}, $strict_obj, E('/', 'Properties not allowed: toto.'));
for my $item ($strict_obj->compile, $strict_obj) {
  joi_ok([{ns => 'plop', toto => 'plouf'}], joi->array->strict->items($item), E('/0', 'Properties not allowed: toto.'),
  );
}

note "can omit non-required objects containing required properties";
joi_ok({}, joi->object->props(a => joi->object->props(b => joi->integer->required)));

note "must include required objects containing required properties";
joi_ok(
  {},
  joi->object->props(a => joi->object->required->props(b => joi->integer->required)),
  E('/a', 'Missing property.'),
);

eval { joi->number->extend(joi->integer) };
like $@, qr{Cannot extend joi 'number' by 'integer'}, 'need to extend same type';

test_extend(
  joi->array->min(0)->max(10),
  joi->array->min(5),
  {type => 'array', minItems => 5, maxItems => 10},
  'extended array',
);

test_extend(
  joi->array->items([joi->integer]),                joi->array->items([joi->number]),
  {type => 'array', items => [{type => 'number'}]}, 'extended items in an array',
);

test_extend(
  joi->integer->min(0)->max(10),
  joi->integer->min(5),
  {type => 'integer', minimum => 5, maximum => 10},
  'extended integer',
  'extended integer',
);

test_extend(
  joi->object->props(x => joi->integer, y => joi->integer),
  joi->object->props(x => joi->number),
  {type => 'object', properties => {x => {type => 'number'}, y => {type => 'integer'}}},
  'extended object',
);

is_deeply(
  edj(joi->object->props(ip => joi->type([qw(string null)])->format('ip'), ns => joi->string)),
  {type => 'object', properties => {ip => {format => 'ip', type => [qw(string null)]}, ns => {type => 'string'}}},
  'null or string',
);

test_extend(
  joi->object->props(a => joi->integer, b => joi->integer->required),
  joi->object->props(b => joi->integer->required, x => joi->string->required, y => joi->string->required),
  {
    type       => 'object',
    required   => bag(qw(b x y)),
    properties =>
      {a => {type => 'integer'}, b => {type => 'integer'}, x => {type => 'string'}, y => {type => 'string'}},
  },
  'extended object with required',
);

done_testing;

sub test_extend {
  my ($joi, $by, $expected, $description) = @_;
  my $joi_clone = dclone $joi;
  my $by_clone  = dclone $by;

  cmp_deeply(edj($joi->extend($by)), $expected, $description);
  cmp_deeply $joi, $joi_clone, "$description did not mutate \$joi";
  cmp_deeply $by,  $by_clone,  "$description did not mutate \$by";
}
