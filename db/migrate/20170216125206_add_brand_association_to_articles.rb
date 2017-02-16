class AddBrandAssociationToArticles < ActiveRecord::Migration[5.0]
  def change
    add_reference :articles, :brand, foreign_key: true

    Article.all.each do |a|
      if brand = Brand.where(slug: a.tag).first
        a.update(brand: brand)
      end
    end
  end
end
