use utf8;
package WriteOff::Schema::Result::ImageStory;

use strict;
use warnings;
use base "WriteOff::Schema::Result";

__PACKAGE__->table("image_story");

__PACKAGE__->add_columns(
	"image_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
	"story_id",
	{ data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("image_id", "story_id");
__PACKAGE__->belongs_to("image", "WriteOff::Schema::Result::Image", "image_id");
__PACKAGE__->belongs_to("story", "WriteOff::Schema::Result::Story", "story_id");

1;
