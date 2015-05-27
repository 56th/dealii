// ---------------------------------------------------------------------
//
// Copyright (C) 2015 by the deal.II authors
//
// This file is part of the deal.II library.
//
// The deal.II library is free software; you can use it, redistribute
// it, and/or modify it under the terms of the GNU Lesser General
// Public License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
// The full text of the license can be found in the file LICENSE at
// the top level of the deal.II distribution.
//
// ---------------------------------------------------------------------

// Test preconditioner_from_diagonal_inverse:

#include "../tests.h"

#include <deal.II/lac/block_linear_operator.h>
#include <deal.II/lac/block_sparse_matrix.h>
#include <deal.II/lac/block_vector.h>
#include <deal.II/lac/dynamic_sparsity_pattern.h>
#include <deal.II/lac/sparse_matrix.h>
#include <deal.II/lac/vector.h>

#define PRINTME(name, var) \
  deallog << "Block vector: " name << ":" << std::endl; \
  for (unsigned int i = 0; i < var.n_blocks(); ++i) \
    deallog << "[block " << i << " ]  " << var.block(i);


using namespace dealii;

int main()
{
  initlog();
  deallog << std::setprecision(12);

  // BlockSparseMatrix:
  {
    BlockDynamicSparsityPattern dsp(3, 3);
    for (unsigned int i = 0; i < 3; ++i)
      for (unsigned int j = 0; j < 3; ++j)
        dsp.block(i, j).reinit (1, 1);
    dsp.collect_sizes ();

    BlockSparsityPattern sparsity_pattern;
    sparsity_pattern.copy_from(dsp);
    sparsity_pattern.compress();

    BlockSparseMatrix<double> a (sparsity_pattern);
    for (unsigned int i = 0; i < 3; ++i)
    {
      a.block(i,i).set(0, 0, i+i +1);
      for (unsigned int j = 0; j < i; ++j)
        a.block(i,j).set(0, 0, 10);
    }

    BlockSparseMatrix<double> d(sparsity_pattern);
    for (unsigned int i = 0; i < 3; ++i)
        d.set(i,i, 1.0 / (i+i +1) );

    auto op_a         = linear_operator< BlockVector<double> >(a);
    auto diagonal_inv = linear_operator< BlockVector<double> >(d);
    // auto diagonal_inv = block_diagonal_operator(diag);
    auto inverse_op_a = block_triangular_inverse< BlockVector<double>, BlockVector<double>, BlockSparseMatrix<double> >(a, diagonal_inv);

    auto identity = inverse_op_a * op_a;

    BlockVector<double> u;
    BlockVector<double> v;

    deallog << " -- Matrix -- " << std::endl;
    op_a.reinit_domain_vector(u, false);
    op_a.reinit_range_vector(v, false);
    for(unsigned int j = 0; j<3; ++j)
    {
      for(unsigned int i = 0; i<3; ++i)
      {
        u.block(i)[0] = 0;;
        v.block(i)[0] = 0;
      }
      u.block(j)[0] = 1;;

      op_a.vmult(v, u);

      PRINTME("v", v);
    }

    deallog << " -- Inverse -- " << std::endl;
    inverse_op_a.reinit_domain_vector(u, false);
    inverse_op_a.reinit_range_vector(v, false);
    for(unsigned int j = 0; j<3; ++j)
    {
      for(unsigned int i = 0; i<3; ++i)
      {
        u.block(i)[0] = 0;
        v.block(i)[0] = 0;
      }
      u.block(j)[0] = 1;;

      inverse_op_a.vmult(v, u);

      PRINTME("v", v);
    }

    deallog << " -- Identity -- " << std::endl;
    identity.reinit_domain_vector(u, false);
    identity.reinit_range_vector(v, false);
    for(unsigned int j = 0; j<3; ++j)
    {
      for(unsigned int i = 0; i<3; ++i)
      {
        u.block(i)[0] = 0;;
        v.block(i)[0] = 0;
      }
      u.block(j)[0] = 1;;

      identity.vmult(v, u);

      PRINTME("v", v);
    }
  }
}
