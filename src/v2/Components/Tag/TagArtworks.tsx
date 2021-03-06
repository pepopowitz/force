import { ContextModule } from "@artsy/cohesion"
import { TagArtworks_tag } from "v2/__generated__/TagArtworks_tag.graphql"
import { Mediator } from "v2/Artsy"
import ArtworkGrid from "v2/Components/ArtworkGrid"
import React from "react"
import {
  RelayPaginationProp,
  createPaginationContainer,
  graphql,
} from "react-relay"
import styled from "styled-components"
import { Filters } from "."
import Dropdown from "../ArtworkFilter/Dropdown"
import ForSaleCheckbox from "../ArtworkFilter/ForSaleCheckbox"
import Headline from "../ArtworkFilter/Headline"
import TotalCount from "../ArtworkFilter/TotalCount"
import BorderedPulldown from "../BorderedPulldown"
import Spinner from "../Spinner"

interface Props extends Filters {
  mediator: Mediator
  relay: RelayPaginationProp
  tag: TagArtworks_tag
  onDropdownSelected: (slice: string, value: string) => void
  onSortSelected: (sort: string) => void
  onForSaleToggleSelected: () => void
  sort?: string
}

export interface State {
  loading: boolean
}

const SpinnerContainer = styled.div`
  width: 100%;
  height: 100px;
  position: relative;
`

const PageSize = 10

const FilterBar = styled.div`
  vertical-align: middle;
  text-align: center;

  > div {
    display: inline-block;
  }
`

const SubFilterBar = styled.div`
  display: flex;
  justify-content: space-between;
  padding: 40px 0 20px;
  align-items: center;
`

export class TagArtworks extends React.Component<Props, State> {
  private finishedPaginatingWithError = false

  state = {
    loading: false,
  }

  loadMoreArtworks() {
    const hasMore = this.props.tag.filtered_artworks.pageInfo.hasNextPage
    const origLength = this.props.tag.filtered_artworks.edges.length
    if (hasMore && !this.state.loading && !this.finishedPaginatingWithError) {
      this.setState({ loading: true }, () => {
        this.props.relay.loadMore(PageSize, error => {
          if (error) {
            console.error(error)
          }
          const newLength = this.props.tag.filtered_artworks.edges.length
          const newHasMore = this.props.tag.filtered_artworks.pageInfo
            .hasNextPage
          if (newLength - origLength < PageSize && newHasMore) {
            console.error(
              `Total count inconsistent with actual records returned for tag: ${this.props.tag.slug}`
            )
            this.finishedPaginatingWithError = true
          }
          this.setState({ loading: false })
        })
      })
    }
  }

  renderDropdown() {
    const getSelected = slice => {
      if (slice === "price_range") return "priceRange"
      if (slice === "dimension_range") return "dimensionRange"
      return slice
    }
    return this.props.tag.filtered_artworks.aggregations.map(aggregation => {
      return (
        <Dropdown
          aggregation={aggregation}
          key={aggregation.slice}
          selected={
            aggregation.slice &&
            this.props[getSelected(aggregation.slice.toLowerCase())]
          }
          onSelected={this.props.onDropdownSelected}
        />
      )
    })
  }

  renderForSaleToggle() {
    return (
      <ForSaleCheckbox
        checked={this.props.forSale}
        onChange={this.props.onForSaleToggleSelected}
      />
    )
  }

  renderArtworks() {
    const pulldownOptions = [
      { val: "-partner_updated_at", name: "Recently Updated" },
      { val: "-year", name: "Artwork Year (desc.)" },
      { val: "year", name: "Artwork Year (asc.)" },
    ]
    const selectedSort = pulldownOptions.find(
      sort => sort.val === this.props.sort
    )

    return (
      <div>
        <SubFilterBar>
          <div style={{ lineHeight: "1.8em" }}>
            <Headline
              medium={this.props.medium}
              priceRange={this.props.priceRange}
              dimensionRange={this.props.dimensionRange}
              forSale={this.props.forSale}
              facet={this.props.tag.filtered_artworks.facet}
              aggregations={this.props.tag.filtered_artworks.aggregations}
            />
            <TotalCount filter_artworks={this.props.tag.filtered_artworks} />
          </div>
          <BorderedPulldown
            defaultValue="Recently Updated"
            selectedName={selectedSort && selectedSort.name}
            options={pulldownOptions}
            onChange={this.props.onSortSelected}
          />
        </SubFilterBar>
        <div>
          <ArtworkGrid
            artworks={this.props.tag.filtered_artworks as any}
            columnCount={4}
            itemMargin={40}
            onLoadMore={() => this.loadMoreArtworks()}
            mediator={this.props.mediator}
            contextModule={ContextModule.artworkGrid}
          />
          <SpinnerContainer>
            {this.state.loading ? <Spinner /> : ""}
          </SpinnerContainer>
        </div>
      </div>
    )
  }

  render() {
    return (
      <div>
        <FilterBar>
          {this.renderForSaleToggle()}
          {this.renderDropdown()}
        </FilterBar>
        {this.renderArtworks()}
      </div>
    )
  }
}

export default createPaginationContainer(
  TagArtworks,
  {
    tag: graphql`
      fragment TagArtworks_tag on Tag
        @argumentDefinitions(
          forSale: { type: "Boolean" }
          medium: { type: "String", defaultValue: "*" }
          aggregations: {
            type: "[ArtworkAggregation]"
            defaultValue: [MEDIUM, TOTAL, PRICE_RANGE, DIMENSION_RANGE]
          }
          priceRange: { type: "String", defaultValue: "*" }
          dimensionRange: { type: "String", defaultValue: "*" }
          count: { type: "Int", defaultValue: 10 }
          cursor: { type: "String", defaultValue: "" }
          sort: { type: "String", defaultValue: "-partner_updated_at" }
        ) {
        slug
        filtered_artworks: filterArtworksConnection(
          aggregations: $aggregations
          forSale: $forSale
          medium: $medium
          priceRange: $priceRange
          dimensionRange: $dimensionRange
          sort: $sort
          first: $count
          after: $cursor
        ) @connection(key: "TagArtworks_filtered_artworks") {
          ...TotalCount_filter_artworks
          aggregations {
            slice
            counts {
              name
              value
            }
            ...Dropdown_aggregation
          }
          facet {
            ...Headline_facet
          }
          id

          pageInfo {
            hasNextPage
            endCursor
          }
          ...ArtworkGrid_artworks
          edges {
            node {
              id
            }
          }
        }
      }
    `,
  },
  {
    direction: "forward",
    getConnectionFromProps(props) {
      return props.tag.filtered_artworks
    },
    getFragmentVariables(prevVars, totalCount) {
      return {
        ...prevVars,
        count: totalCount,
      }
    },
    getVariables(props, { count, cursor }, fragmentVariables) {
      return {
        // in most cases, for variables other than connection filters like
        // `first`, `after`, etc. you may want to use the previous values.
        ...fragmentVariables,
        count,
        cursor,
        tagID: props.tag.slug,
      }
    },
    query: graphql`
      query TagArtworksPaginationQuery(
        $tagID: String!
        $count: Int!
        $cursor: String
        $sort: String
        $priceRange: String
        $dimensionRange: String
        $medium: String
        $forSale: Boolean
      ) {
        tag(id: $tagID) {
          ...TagArtworks_tag
            @arguments(
              count: $count
              cursor: $cursor
              sort: $sort
              priceRange: $priceRange
              dimensionRange: $dimensionRange
              medium: $medium
              forSale: $forSale
            )
        }
      }
    `,
  }
)
