use strict;
use lib qw(t/lib);
use dbixcsl_common_tests;
use Test::More;
use List::MoreUtils 'apply';

my $dsn      = $ENV{DBICTEST_PG_DSN} || '';
my $user     = $ENV{DBICTEST_PG_USER} || '';
my $password = $ENV{DBICTEST_PG_PASS} || '';

my $tester = dbixcsl_common_tests->new(
    vendor      => 'Pg',
    auto_inc_pk => 'SERIAL NOT NULL PRIMARY KEY',
    dsn         => $dsn,
    user        => $user,
    password    => $password,
    extra       => {
        create => [
            q{
                CREATE TABLE pg_loader_test1 (
                    id SERIAL NOT NULL PRIMARY KEY,
                    value VARCHAR(100)
                )
            },
            q{
                COMMENT ON TABLE pg_loader_test1 IS 'The Table'
            },
            q{
                COMMENT ON COLUMN pg_loader_test1.value IS 'The Column'
            },
            # Test to make sure data_types that don't need a size => don't
            # have one.
            q{
                CREATE TABLE pg_loader_test2 (
                    id SERIAL NOT NULL PRIMARY KEY,
                    a_bigint BIGINT,
                    an_int8 INT8,
                    a_bigserial BIGSERIAL,
                    a_serial8 SERIAL8,
                    a_bit BIT,
                    a_bit_varying_with_precision BIT VARYING(8),
                    a_boolean BOOLEAN,
                    a_bool BOOL,
                    a_box BOX,
                    a_bytea BYTEA,
                    a_cidr CIDR,
                    a_circle CIRCLE,
                    a_date DATE,
                    a_double_precision DOUBLE PRECISION,
                    a_float8 FLOAT8,
                    an_inet INET,
                    an_integer INTEGER,
                    an_int INT,
                    an_int4 INT4,
                    an_interval INTERVAL,
                    an_interval_with_precision INTERVAL(2),
                    a_line LINE,
                    an_lseg LSEG,
                    a_macaddr MACADDR,
                    a_money MONEY,
                    a_path PATH,
                    a_point POINT,
                    a_polygon POLYGON,
                    a_real REAL,
                    a_float4 FLOAT4,
                    a_smallint SMALLINT,
                    an_int2 INT2,
                    a_serial SERIAL,
                    a_serial4 SERIAL4,
                    a_text TEXT,
                    a_time TIME,
                    a_time_with_precision TIME(2),
                    a_time_without_time_zone TIME WITHOUT TIME ZONE,
                    a_time_without_time_zone_with_precision TIME(2) WITHOUT TIME ZONE,
                    a_time_with_time_zone TIME WITH TIME ZONE,
                    a_time_with_time_zone_with_precision TIME(2) WITH TIME ZONE,
                    a_timestamp TIMESTAMP,
                    a_timestamp_with_precision TIMESTAMP(2),
                    a_timestamp_without_time_zone TIMESTAMP WITHOUT TIME ZONE,
                    a_timestamp_without_time_zone_with_precision TIMESTAMP(2) WITHOUT TIME ZONE,
                    a_timestamp_with_time_zone TIMESTAMP WITH TIME ZONE,
                    a_timestamp_with_time_zone_with_precision TIMESTAMP(2) WITH TIME ZONE
                )
            },
        ],
        drop  => [ qw/ pg_loader_test1 pg_loader_test2 / ],
        count => 49,
        run   => sub {
            my ($schema, $monikers, $classes) = @_;

            my $class    = $classes->{pg_loader_test1};
            my $filename = $schema->_loader->_get_dump_filename($class);

            my $code = do {
                local ($/, @ARGV) = (undef, $filename);
                <>;
            };

            like $code, qr/^=head1 NAME\n\n^$class - The Table\n\n^=cut\n/m,
                'table comment';

            like $code, qr/^=head2 value\n\n(.+:.+\n)+\nThe Column\n\n/m,
                'column comment and attrs';

            my $rsrc = $schema->resultset('PgLoaderTest2')->result_source;
            my @type_columns = grep !/^id\z/, $rsrc->columns;
            my @without_precision = grep !/_with_precision\z/, @type_columns;
            my @with_precision    = grep  /_with_precision\z/, @type_columns;
            my %with_precision;
            @with_precision{
                apply { s/_with_precision\z// } @with_precision
            } = ();

            for my $col (@without_precision) {
                my ($data_type) = $col =~ /^an?_(.*)/;
                ($data_type = uc $data_type) =~ s/_/ /g;

                ok((not exists $rsrc->column_info($col)->{size}),
                    "$data_type " .
                    (exists $with_precision{$col} ? 'without precision ' : '') .
                    "has no 'size' column_info");
            }

            for my $col (@with_precision) {
                my ($data_type) = $col =~ /^an?_(.*)_with_precision\z/;
                ($data_type = uc $data_type) =~ s/_/ /g;

                ok($rsrc->column_info($col)->{size},
                    "$data_type with precision has a 'size' column_info");
            }
        },
    },
);

if( !$dsn || !$user ) {
    $tester->skip_tests('You need to set the DBICTEST_PG_DSN, _USER, and _PASS environment variables');
}
else {
    $tester->run_tests();
}
