package WriteOff::Schema::Result::Virtual::Artist;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('Artist');

__PACKAGE__->add_columns(
	"name",
	{ data_type => "text" },
	"user_id",
	{ data_type => "integer" },
);

__PACKAGE__->belongs_to(
  "user",
  "WriteOff::Schema::Result::User",
  { id => "user_id" },
);

__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q{
	SELECT artist AS name, user_id FROM images
		UNION
	SELECT author AS name, user_id FROM storys
		UNION
	SELECT username AS name, id AS user_id FROM users
});

__PACKAGE__->result_source_instance->deploy_depends_on([
	"WriteOff::Schema::Result::Story",
	"WriteOff::Schema::Result::Image",
	"WriteOff::Schema::Result::User",
]);

1;
