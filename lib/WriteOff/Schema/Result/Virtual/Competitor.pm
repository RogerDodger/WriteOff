package WriteOff::Schema::Result::Virtual::Competitor;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('Competitor');

__PACKAGE__->add_columns(
	"competitor",
	{ data_type => "text" },
	"user_id",
	{ data_type => "integer" },
);

__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(
	"SELECT artist AS competitor, user_id FROM images" . " " .
	"UNION" . " " . 
	"SELECT author AS competitor, user_id FROM storys"
);

__PACKAGE__->result_source_instance->deploy_depends_on([
	"WriteOff::Schema::Result::Story", "WriteOff::Schema::Result::Image"
]);

1;